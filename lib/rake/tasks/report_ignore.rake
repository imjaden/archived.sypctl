# encoding: utf-8
require 'uri'
require 'logger'
require 'timeout'
require 'securerandom'
require 'settingslogic'
require 'lib/utils/mail_sender'
require 'lib/sinatra/extension_redis'
require 'active_support/core_ext/string'
require 'lib/utils/template_v1_engine'
require 'lib/utils/template_v2_engine'
require 'lib/utils/template_v3_engine'
require 'lib/utils/template_v4_engine'
require 'lib/utils/template_v5_engine'
require 'lib/utils/template_v10_engine'
require 'lib/utils/template_instance_methods'

namespace :report do
  IGNORED_REPORT_CACHE_PID    = 'report_cache_ignore'.freeze
  IGNORED_REPORT_REDIS_FORMAT = 'cache/ignored/report/%s'.freeze
  IGNORED_REPORT_REDIS_KEY    = 'cache/ignored/report'.freeze

  def refresh_ignored_report_data_cache(report_id, redis_format_key, refresh_type, index = 0, current_timestamp = Time.now)
    refresh_type, code_exception_messages, data_exception_messages = 'ignore', [], []
    return false unless report = Report.find_by(report_id: report_id)
    return false unless report.configuration_tables.count <= 4
    is_exit, message = exit_when_report_data_table_empty(report)

    if is_exit
      data_exception_messages.push("报表数据表为空或异常，报表标题：#{report.title}，ID:#{report.report_id}, 异常内容：#{message}")
    else
      timestamp = ::TimestampManager.report_data_timestamp(report_id).to_s
      redis_key = format(redis_format_key, report_id)
      return false if (redis.exists(redis_key) && redis.hget(redis_key, 'updated_at') == timestamp)

      start_time = Time.now
      action_log = ReportCacheActionLog.create({refresh_type: refresh_type, report_id: report.report_id, report_name: report.title, template_id: report.template_id, timestamp: timestamp, begin_time: start_time})

      report.make_sure_cache_path_exist

      refresh_constraint = ::ReportCacheRefreshConstraint.fetch(report.report_id)
      timeout_per_ignore = refresh_constraint.timeout_per_ignore || 60 * 60 * 1.5
      ignored_group_ids  = (refresh_constraint.ignore_groups || '').split(",").compact.uniq.reject(&:empty?)
      ignored_group_ids  = [0] if Report.ignore_groups_template_ids.include?(report.template_id)

      puts "#{report.title}(#{report.report_id}) ignored_group_ids: #{ignored_group_ids}"
      begin
        ignored_group_ids.each do |group_id|
          begin
            Timeout::timeout(timeout_per_ignore) do
              generate_cache_javascript_file(index, report, group_id, timestamp)
            end
          rescue Timeout::Error
              data_exception_messages.push("进程(#{index}) 刷新单报表:#{report.title}(#{report_id})(忽略) 单群组(#{group_id}) 超时 #{timeout_per_ignore}s")
          rescue => e
            exception_backtraces = ["#{__FILE__}:#{__LINE__} - #{e.message}"]
            exception_backtraces += e.backtrace.select { |info| info.start_with?(Dir.pwd) }
            code_exception_messages.push(exception_backtraces.join("\n"))
          end
        end
      rescue => e
        exception_backtraces = ["#{__FILE__}:#{__LINE__} - #{e.message}"]
        exception_backtraces += e.backtrace.select { |info| info.start_with?(Dir.pwd) }
        code_exception_messages.push(exception_backtraces.join("\n"))
      end
      redis_key = format(redis_format_key, report_id)
      update_redis_key_value(redis_key, 'updated_at', timestamp)
      action_log.update_columns({group_count: ignored_group_ids.count, end_time: Time.now, duration: Time.now - start_time})
      report_task_logger.info(format('%s; %s; %s; %s; %.2fs', current_timestamp, report_id, ignored_group_ids.count, timestamp, Time.now - start_time))
    end
  rescue => e
    exception_backtraces = ["#{__FILE__}:#{__LINE__} - #{e.message}"]
    exception_backtraces += e.backtrace.select { |info| info.start_with?(Dir.pwd) }
    code_exception_messages.push(exception_backtraces.join("\n"))
  ensure
    unless data_exception_messages.empty?
      data_exception_receivers = ::WConfig.fetch('sypc_000011')
      exception_title = "#{report.title if report},刷新缓存出现#{data_exception_messages.length}个数据异常"
      puts data_exception_messages.join("\n")
      ::BangBoom.create_with_sms_notification(exception_title, data_exception_messages.join("\n"), data_exception_receivers)
    end

    unless code_exception_messages.empty?
      code_exception_receivers = ::WConfig.fetch('sypc_000012')
      exception_title = "#{report.title if report},刷新缓存出现#{code_exception_messages.length}个代码异常"
      puts code_exception_messages.join("\n")
      ::BangBoom.create_with_sms_notification(exception_title, code_exception_messages.join("\n"), code_exception_receivers)
    end
  end

  namespace :cache do
    desc 'generate ignored report cache with redis'
    task ignore: :environment do |t, args|
      register Sinatra::Redis
      include ::Template::InstanceMethods

      begin
        redis.ping
        puts 'redis ping successfully'
        ActiveRecord::Base.establish_connection
        version = ActiveRecord::Base.connection.execute("select version();").map(&:inspect).flatten.join
        puts "mysql(#{version}) connect successfully"
      rescue Exception => e
        puts "#{__FILE__}:#{__LINE__} - #{e.message}"
        exit
      end

      refresh_type     = 'ignore'
      task_pid_file    = IGNORED_REPORT_CACHE_PID
      redis_status_key = IGNORED_REPORT_REDIS_KEY
      redis_format_key = IGNORED_REPORT_REDIS_FORMAT

      exit_when_redis_not_match(redis_status_key, 'status', 'running')

      report_ids = Report.all.map(&:report_id)
      current_timestamp = report_ids.empty? ? 'null' : ::TimestampManager.report_data_timestamp(report_ids).to_s

      exit_when_redis_not_match(redis_status_key, 'updated_at', current_timestamp)
      update_redis_key_value(redis_status_key, 'status', 'running')

      start_time = Time.now
      generate_pid_file(task_pid_file, Process.pid)
      report_task_logger(refresh_type).info(format('start; %s; %s; %s; -; %s', Process.pid, refresh_type, current_timestamp, report_ids.join(',')))

      threads = []
      report_ids.each_with_index do |report_id, index|
        threads << Thread.new(report_id, index) do |report_id, index|
          refresh_ignored_report_data_cache(report_id, redis_format_key, refresh_type, index, current_timestamp)
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
end
