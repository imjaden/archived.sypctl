# encoding: utf-8
require 'uri'
require 'logger'
require 'timeout'
require 'securerandom'
require 'settingslogic'
require 'lib/utils/mail_sender'
require 'lib/sinatra/extension_redis'
require 'active_support/core_ext/string'
require 'lib/utils/template_instance_methods'

namespace :saas do
  namespace :report do
    SAAS_REPORT_CACHE_REALTIME_PID  = format('%s_report_cache_realtime', ENV['DATABASE']).freeze
    SAAS_REPORT_CACHE_WASTETIME_PID = format('%s_report_cache_wastetime', ENV['DATABASE']).freeze
    SAAS_REPORT_CACHE_NORMAL_PID    = format('%s_report_cache_normal', ENV['DATABASE']).freeze
    SAAS_REPORT_CACHE_REFRESH_PID   = format('%s_report_cache_refresh', ENV['DATABASE']).freeze
    SAAS_REPORT_REDIS_KEY           = "cache/#{ENV['DATABASE']}/report/%s".freeze
    SAAS_REPORT_REALTIME_REDIS_KEY  = format('cache/%s/report/realtime', ENV['DATABASE']).freeze
    SAAS_REPORT_WASTETIME_REDIS_KEY = format('cache/%s/report/wastetime', ENV['DATABASE']).freeze
    SAAS_REPORT_NORMAL_REDIS_KEY    = format('cache/%s/report/normal', ENV['DATABASE']).freeze
    SAAS_REPORT_REFRESH_REDIS_KEY   = format('cache/%s/report/refresh', ENV['DATABASE']).freeze

    namespace :cache do
      desc 'make sure all groups report cache generated'
      task omit: :environment do
        include ::Template::InstanceMethods

        refresh_report_omit_groups(ENV['REPORT_ID'])
      end

      desc 'refresh all reports'
      task :refresh do
        Rake::Task['saas:report:cache:_refresh_middleware'].invoke('refresh')
      end

      desc 'unrealtime reports'
      task :normal do
        Rake::Task['saas:report:cache:_refresh_middleware'].invoke('normal')
      end

      desc 'realtime reports'
      task :realtime do
        Rake::Task['saas:report:cache:_refresh_middleware'].invoke('realtime')
      end

      desc 'wastetime reports'
      task :wastetime do
        Rake::Task['saas:report:cache:_refresh_middleware'].invoke('wastetime')
      end

      desc 'report ids'
      task report_ids: :environment do
        (ENV['REPORT_IDS'] || ENV['IDS'] || '').split(',').map(&:strip).compact.each_with_index do |report_id, index|
          refresh_report_data_cache_with_group_ids(report_id, SAAS_REPORT_REDIS_KEY, (ENV['GROUP_IDS'] || "").split(",").map(&:to_i))
        end
      end

      desc 'generate part report cache with redis within rescue'
      task :_refresh_middleware, [:refresh_type] do |t, args|
        begin
          refresh_type = args.fetch(:refresh_type, 'unknow_refresh_type')

          unless %w(realtime normal wastetime refresh).include?(refresh_type)
            puts format('unknow report type: %s', refresh_type); exit
          end

          Rake::Task['report:cache:_refresh'].invoke(refresh_type)
        rescue => exception
          rescue_report_task(exception, refresh_type)

          Rake::Task['boom:notify_deliver'].invoke
        end
      end

      desc 'generate all report cache with redis'
      task :_refresh, [:refresh_type] => :environment do |t, args|
        register Sinatra::Redis
        include ::Template::InstanceMethods

        begin
          redis.ping
          puts 'redis ping successfully'
          ActiveRecord::Base.establish_connection
          version = ActiveRecord::Base.connection.execute("select version();").map(&:inspect).flatten.join
          puts "mysql(#{version}) connect successfully"
        rescue Exception => e
          puts "#{Time.now}: #{__FILE__}@#{__LINE__} - #{e.message}"
          exit
        end

        refresh_type = args.fetch(:refresh_type, 'unknow_refresh_type')
        config = {
          realtime: {
            title: '实时报表',
            pid: SAAS_REPORT_CACHE_REALTIME_PID,
            status_key: SAAS_REPORT_REALTIME_REDIS_KEY,
            sql: "refresh_type = '#{refresh_type}'"
          },
          normal: {
            title: '常规报表',
            pid: SAAS_REPORT_CACHE_NORMAL_PID,
            status_key: SAAS_REPORT_NORMAL_REDIS_KEY,
            sql: "refresh_type = '#{refresh_type}' or 1 = 1"
          },
          wastetime: {
            title: '耗时报表',
            pid: SAAS_REPORT_CACHE_WASTETIME_PID,
            status_key: SAAS_REPORT_WASTETIME_REDIS_KEY,
            sql: "refresh_type = '#{refresh_type}'"
          },
          refresh: {
            title: '所有报表',
            pid: SAAS_REPORT_CACHE_REFRESH_PID,
            status_key: SAAS_REPORT_REFRESH_REDIS_KEY,
            sql: %(1 = 1)
          }
        }
        config_hash      = config.fetch(refresh_type.to_sym, {})
        task_pid_file    = config_hash[:pid]
        redis_status_key = config_hash[:status_key]
        sql_condition    = config_hash[:sql]
        redis_format_key = SAAS_REPORT_REDIS_KEY

        exit_when_redis_not_match(redis_status_key, 'status', 'running')

        report_ids = Report.where(sql_condition).map(&:report_id)
        current_timestamp = report_ids.empty? ? 'null' : ::TimestampManager.report_data_timestamp(report_ids).to_s

        exit_when_redis_not_match(redis_status_key, 'updated_at', current_timestamp)
        update_redis_key_value(redis_status_key, 'status', 'running')

        start_time = Time.now
        generate_pid_file(task_pid_file, Process.pid)
        report_ids = updated_report_ids(report_ids, redis_format_key)
        report_task_logger(refresh_type).info(format('start; %s; %s; %s; -; %s', Process.pid, refresh_type, current_timestamp, report_ids.join(',')))

        threads = []
        report_ids.each_with_index do |report_id, index|
          threads << Thread.new(report_id, index) do |report_id, index|
            refresh_report_data_cache(report_id, redis_format_key, refresh_type, index, current_timestamp)
          end
          threads.each(&:join) if threads.count == concurrent_thread_count(refresh_type)
          threads.keep_if(&:status)
        end
        threads.each(&:join) unless threads.empty?

        collect_report_crash_into_boom
        delete_pid_file(task_pid_file)
        update_redis_key_value(redis_status_key, 'status', 'done')
        update_redis_key_value(redis_status_key, 'updated_at', current_timestamp)
        info = format('done; %s; %s; %s; %ss; %s', Process.pid, refresh_type, current_timestamp, Time.now - start_time, report_ids.join(','))
        report_task_logger.info(info); puts info

        # 清理符合如下条件的文件:
        #   1. project/tmp/js/ 文件夹下
        #   2. 普通文件类型
        #   3. 文件名后缀为.js | .error
        #   4. 修改时间在2天以前（1天会误删除，00:01 删除昨天 23:59 生成的缓存文件）
        # `find #{ENV['APP_ROOT_PATH']}/tmp/js/ -type f -name '*.{js,error}' -mtime +2 -exec rm -f {} \\;`
      end
    end

    task timestamp: :environment do
      register Sinatra::Redis
      list = Report.all.map do |report|
        message, color_code = "正常", 5
        if timestamp = ::TimestampManager.report_data_timestamp(report.report_id)
          redis_key = format(SAAS_REPORT_REDIS_KEY, report.report_id)
          updated_at = redis.hget(redis_key, 'updated_at')
          updated_at = Time.parse(updated_at) if updated_at
          if !updated_at || updated_at > timestamp
            redis.hmset(redis_key, ['updated_at', timestamp.to_s])
            message, color_code = "异常，已重置", 33
          end
        else
          message, color_code = "BUG 未配置时间戳", 31
        end
        ["#{report.title}/#{report.report_id}", report.template_id, report.configuration_tables.count, message, timestamp, updated_at]
      end

      puts Terminal::Table.new(headings: ['报表', '模板', '关联表数', '状态', 'mysql', 'redis'], rows: list)
    end
  end
end