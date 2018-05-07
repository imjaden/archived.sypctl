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

namespace :report do
  REPORT_CACHE_REALTIME_PID  = 'report_cache_realtime'.freeze
  REPORT_CACHE_WASTETIME_PID = 'report_cache_wastetime'.freeze
  REPORT_CACHE_NORMAL_PID    = 'report_cache_normal'.freeze
  REPORT_CACHE_REFRESH_PID   = 'report_cache_refresh'.freeze
  REPORT_REDIS_KEY           = 'cache/report/%s'.freeze
  REPORT_REALTIME_REDIS_KEY  = 'cache/report/realtime'.freeze
  REPORT_WASTETIME_REDIS_KEY = 'cache/report/wastetime'.freeze
  REPORT_NORMAL_REDIS_KEY    = 'cache/report/normal'.freeze
  REPORT_REFRESH_REDIS_KEY   = 'cache/report/refresh'.freeze

  # TODO: 1. use eval, 2. check table_name exist in database
  def define_model(table_name)
    model_content = <<-EOF.strip_heredoc
      # encoding: utf-8
      require 'sinatra/activerecord'

      # model: automatic defined
      class #{table_name.to_s.camelize} < ActiveRecord::Base
          self.table_name = '#{table_name}'
      end
    EOF

    model_path = app_tmp_join(%(rb/#{table_name}.rb))
    File.open(model_path, 'w:utf-8') { |file| file.puts(model_content) }

    require model_path
  end

  def class_get(table_name, control_type = '')
    if !table_name || table_name.strip.empty?
      raise "error: report control `#{control_type}` not config `table_name`!"
    end
    _class_get(table_name)
  end

  def _class_get(table_name)
    # Object.const_get(table_name.camelize)
    table_name.to_s.camelize.constantize
  rescue NameError
    define_model(table_name)
    _class_get(table_name)
  end

  def report_task_logger(type = 'realtime')
    @report_logger || -> {
      log_path = File.join(ENV['APP_ROOT_PATH'], 'log', %(report_time_consuming_#{type}.log))
      @report_logger = Logger.new(log_path)
      @report_logger.formatter = proc do |severity, datetime, progname, msg|
        "#{datetime.strftime('%Y-%m-%d %H:%M:%S')}; #{msg}\n"
      end
      @report_logger
    }.call
  end

  def exit_when_report_data_table_empty(report)
    return [false, "skip"] if [2, 4].include?(report.template_id)
    table_name = report.configuration_tables.find { |table_name| class_get(table_name).count.zero? }
    [table_name, table_name]
  rescue => e
    puts "#{__FILE__}:#{__LINE__} #{e.message}"
    [true, e.message]
  end

  def generate_report_crash(report_id, exception)
    crash_path = app_tmp_join(%(cache/report/#{report_id}.crash))
    return if File.exist?(crash_path)

    File.open(crash_path, 'w+:utf-8') do |file|
      file.puts(%(发生时间：#{Time.now}，报表（ID=#{report_id}），异常信息 - #{exception.message}))
    end
  end

  def report_data_table_index_daemon(con, table_name, indexs, options = {})
    current_indexs = table_indexs(con, table_name)
    return if (indexs & current_indexs) == indexs

    indexs -= current_indexs
    puts format('alter table %s add index %s', table_name, indexs)
    con.add_index(table_name, indexs, options)
  rescue => e
    puts "failed: alter table #{table_name} add index #{indexs}"
    puts "#{__FILE__}:#{__LINE__} #{e.message}"
  end

  def report_data_tables_index_daemon(con, table_names, is_need_group)
    table_names.compact.reject(&:empty?).each do |table_name|
      report_data_table_index_daemon(con, table_name, [:dim5], {name: 'index_dim5'})

      columns = is_need_group ? [:group_id, :report_id, :part_name] : [:report_id, :part_name]
      report_data_table_index_daemon(con, table_name, columns, {name: "index_#{columns.join('_and_')}"})
    end
  rescue => e
    puts "#{__FILE__}:#{__LINE__} #{e.message}"
  end

  def generate_cache_javascript_file(thread_index, report, group_id, cached_timestamp, is_debug = (ENV['DEBUG'] == "1"))
    javascript_path = report.file_cache_path(group_id, "js")
    runtime_block_within_thread thread_index, "#{ENV['DATABASE']}: #{File.basename(javascript_path)}" do
      begin
        engine = %(::Template::V#{report.template_id}::Engine).camelize.constantize
        engine.new.parse(group_id, report, javascript_path, cached_timestamp, is_debug)
      rescue => exception
        puts "generate_cache_javascript_file: #{exception.message}"
        puts exception.backtrace
        generate_report_crash(report.report_id, exception)
      end
    end
  end

  def collect_report_crash_into_boom
    crash_match_path = app_tmp_join('cache/report/*.crash')
    is_archived_crash = false
    Dir.glob(crash_match_path).each do |crash_path|
      crash_info = File.read(crash_path)
      next if crash_info.nil? || crash_info.empty?

      is_archived_crash = true
      report_id = File.basename(crash_path, '.crash')
      ::BangBoom.create_with_sms_notification("报表(#{report_id})缓存异常", crash_info, ::WConfig.fetch('sypc_000011'))
    end

    if is_archived_crash
      timestamp = Time.now.strftime("%y%m%d%H%M%S")
      archived_path = app_tmp_join("crash/report/#{timestamp}")
      `/bin/mkdir -p #{archived_path}`
      `/bin/mv #{crash_match_path} #{archived_path}/`
    end
  end

  def rescue_report_task(exception, task_command, source_file = __FILE__, line_number = __LINE__)
    human_exception = exception.backtrace.find_all { |info| info.include?(ENV['APP_ROOT_PATH']) }
    human_exception = exception.backtrace.first(15) if human_exception.empty?
    human_exception.unshift(exception.message)

    message = human_exception.select { |path| path.include?(Dir.pwd) }.join("\n")
    receivers = ::WConfig.fetch('sypc_000012')
    ::BangBoom.create_with_sms_notification('刷新报表缓存异常', message, receivers)
  end

  def updated_report_ids(report_ids, redis_format_key, obj_type = 'report#data')
    report_ids.map do |report_id|
      if record = ::TimestampManager.find_by(obj_type: 'report#data', obj_id: report_id)
        redis_cache_key = format(redis_format_key, report_id)
        if redis.hget(redis_cache_key, 'updated_at') != record.timestamp.to_s
          report_id
        end
      else
        report_id
      end
    end.compact.uniq
  end

  def dir_entries(dir_path)
    Dir.entries(dir_path) - %w(. ..)
  end

  def tempalte_report_cached_paths(cache_path)
    dir_entries(cache_path).map do |tempalte_id|
      template_path = File.join(cache_path, tempalte_id)
      if File.directory?(template_path)
        dir_entries(template_path).map do |report_id|
          File.join(template_path, report_id)
        end
      else
        template_path
      end
    end.flatten
  end

  def remove_deprecated_report_cache_paths(cache_type, template_report_paths)
    cache_path = app_tmp_join('cache/' + cache_type)
    cached_paths = tempalte_report_cached_paths(cache_path)
    current_paths = template_report_paths.map { |path| File.join(cache_path, path) }

    (cached_paths - current_paths).each do |deprecated_path|
      `/bin/rm -fr "#{deprecated_path}" > /dev/null 2>&1`
      puts format('%s - %s', Time.now, deprecated_path.sub(ENV['APP_ROOT_PATH'], ''))
    end
  end

  def refresh_report_data_cache(report_id, redis_format_key, refresh_type, index = 0, current_timestamp = Time.now)
    code_exception_messages, data_exception_messages = [], []
    unless report = Report.find_by(report_id: report_id)
      puts "Skip: 报表（id=#{report_id}) 查询失败"
      return false 
    end
    unless report.configuration_tables.count <= 4
      puts "Skip: 报表（id=#{report_id}) 配置档中关联数据表数量（#{report.configuration_tables.count}）过多"
      return false 
    end
    is_exit, message = exit_when_report_data_table_empty(report)

    if is_exit
      data_exception_messages.push("报表数据表为空或异常，报表标题：#{report.title}，ID:#{report.report_id}, 异常内容：#{message}")
    else
      inner_start_time = Time.now
      timestamp        = ::TimestampManager.report_data_timestamp(report_id).to_s
      action_log       = ReportCacheActionLog.create({refresh_type: refresh_type, report_id: report.report_id, report_name: report.title, template_id: report.template_id, timestamp: timestamp, begin_time: inner_start_time})

      report.make_sure_cache_path_exist

      group_ids = [0]
      if Report.need_groups_template_ids.include?(report.template_id)
        group_ids = report.group_ids 
      end

      refresh_constraint = ::ReportCacheRefreshConstraint.fetch(report.report_id)
      timeout_per_report = refresh_constraint.timeout_per_report || 1800
      timeout_per_group  = refresh_constraint.timeout_per_group  || 180
      ignore_groups      = (refresh_constraint.ignore_groups || '').split(",").compact.uniq.reject(&:empty?)

      report_data_tables_index_daemon(ActiveRecord::Base.connection, report.configuration_tables, Report.need_groups_template_ids.include?(report.template_id))

      begin
        group_ids -= ignore_groups
        Timeout::timeout(timeout_per_report) do
          group_ids.each do |group_id|
            begin
              Timeout::timeout(timeout_per_group) do
                generate_cache_javascript_file(index, report, group_id, timestamp)
              end
            rescue Timeout::Error
              data_exception_messages.push("进程(#{index}) 刷新单报表:#{report.title}(#{report_id}) 单群组(#{group_id}) 超时 #{timeout_per_group}s, 忽略组群：#{refresh_constraint.ignore_groups}")
            rescue => e
              exception_backtraces = ["#{__FILE__}:#{__LINE__} - #{e.message}"]
              exception_backtraces += e.backtrace.select { |info| info.start_with?(Dir.pwd) }
              code_exception_messages.push(exception_backtraces.join("\n"))
            end
          end
        end
      rescue Timeout::Error
        data_exception_messages.unshift("进程(#{index}) 刷新报表:#{report.title}(#{report_id}) 超时 #{timeout_per_report}s, 忽略组群：#{refresh_constraint.ignore_groups}")
      rescue => e
        exception_backtraces = ["#{__FILE__}:#{__LINE__} - #{e.message}"]
        exception_backtraces += e.backtrace.select { |info| info.start_with?(Dir.pwd) }
        code_exception_messages.push(exception_backtraces.join("\n"))
      end
      redis_key = format(redis_format_key, report_id)
      update_redis_key_value(redis_key, 'updated_at', timestamp)
      action_log.update_columns({group_count: group_ids.count, end_time: Time.now, duration: Time.now - inner_start_time})
      report_task_logger.info(format('%s; %s; %s; %s; %.2fs', current_timestamp, report_id, group_ids.count, timestamp, Time.now - inner_start_time))
    end
  rescue => e
    exception_backtraces = ["#{__FILE__}:#{__LINE__} - #{e.message}"]
    exception_backtraces += e.backtrace.select { |info| info.start_with?(Dir.pwd) }
    code_exception_messages.push(exception_backtraces.join("\n"))
  ensure
    unless data_exception_messages.empty?
      data_exception_receivers = ::WConfig.fetch('sypc_000011')
      exception_title = "#{report.title if report},刷新缓存出现#{data_exception_messages.length}个数据异常"
      ::BangBoom.create_with_sms_notification(exception_title, data_exception_messages.join("\n"), data_exception_receivers)
    end

    unless code_exception_messages.empty?
      code_exception_receivers = ::WConfig.fetch('sypc_000012')
      exception_title = "#{report.title if report},刷新缓存出现#{code_exception_messages.length}个代码异常"
      ::BangBoom.create_with_sms_notification(exception_title, code_exception_messages.join("\n"), code_exception_receivers)
    end
  end

  def refresh_report_data_cache_with_group_ids(report_id, redis_format_key = REPORT_REDIS_KEY, _group_ids = [])
    unless report = Report.find_by(report_id: report_id)
      puts "Skip: 报表（id=#{report_id}) 查询失败"
      return false 
    end
    unless report.configuration_tables.count <= 4
      puts "Skip: 报表（id=#{report_id}) 配置档中关联数据表数量（#{report.configuration_tables.count}）过多"
      return false 
    end

    start_time = Time.now
    timestamp  = ::TimestampManager.report_data_timestamp(report_id).to_s
    action_log = ReportCacheActionLog.create({refresh_type: 'byhand', report_id: report.report_id, report_name: report.title, template_id: report.template_id, timestamp: timestamp, begin_time: start_time})

    report.make_sure_cache_path_exist
    group_ids = [0]
    if !_group_ids.empty?
      group_ids = _group_ids
    elsif Report.need_groups_template_ids.include?(report.template_id)
      group_ids = report.group_ids
    end

    report_data_tables_index_daemon(ActiveRecord::Base.connection, report.configuration_tables, Report.need_groups_template_ids.include?(report.template_id))

    group_ids.each_with_index do |group_id, index|
      generate_cache_javascript_file(index, report, group_id, timestamp)
    end

    redis_key = format(redis_format_key, report_id)
    update_redis_key_value(redis_key, 'updated_at', timestamp)
    action_log.update_columns({group_count: group_ids.count, end_time: Time.now, duration: Time.now - start_time})
    report_task_logger.info(format('%s; %s; %s; %s; %.2fs', timestamp, report_id, group_ids.count, timestamp, Time.now - start_time))
  rescue => e
    receivers = ::WConfig.fetch('sypc_000012')
    backtrace = e.backtrace.select { |info| info.start_with?(Dir.pwd) }
    backtrace.unshift("#{__FILE__}:#{__LINE__} - #{e.message}")
    ::BangBoom.create_with_sms_notification("刷新报表(ID=#{report_id})缓存异常", backtrace.join("\n"), receivers)
    puts backtrace.join("\n")
  end

  def concurrent_thread_count(refresh_type)
    case refresh_type
    when 'realtime'  then Setting.report_cache_thread.realtime
    when 'wastetime' then Setting.report_cache_thread.wastetime
    when 'normal'    then Setting.report_cache_thread.normal
    when 'ignore'    then Setting.report_cache_thread.ignore
    else                  2
    end
  end

  def refresh_report_omit_groups(report_id)
    unless report = Report.find_by(report_id: report_id)
      puts "Skip: 报表（id=#{report_id}) 查询失败"
      return false 
    end
    unless report.configuration_tables.count <= 4
      puts "Skip: 报表（id=#{report_id}) 配置档中关联数据表数量（#{report.configuration_tables.count}）过多"
      return false 
    end

    start_time = Time.now
    action_log = ReportCacheActionLog.create({refresh_type: 'omit-byhand', report_id: report.report_id, report_name: report.title, template_id: report.template_id, timestamp: Time.now, begin_time: start_time})

    report.make_sure_cache_path_exist
    group_ids = [0]
    if Report.need_groups_template_ids.include?(report.template_id)
      group_ids = report.group_ids
    end

    group_ids.each_with_index do |group_id, index|
      javascript_path = report.file_cache_path(group_id, "js")
      javascript_path = restructure_javascript_path_to_json_path(javascript_path) if [11, 12].include?(report.template_id) 

      generate_cache_javascript_file(index, report, group_id, Time.now) unless File.exists?(javascript_path)
    end

    action_log.update_columns({group_count: group_ids.count, end_time: Time.now, duration: Time.now - start_time})
    report_task_logger.info(format('%s; %s; %s; %s; %.2fs', Time.now, report_id, group_ids.count, Time.now, Time.now - start_time))
  rescue => e
    receivers = ::WConfig.fetch('sypc_000012')
    backtrace = e.backtrace.select { |info| info.start_with?(Dir.pwd) }
    backtrace.unshift("#{__FILE__}:#{__LINE__} - #{e.message}")
    ::BangBoom.create_with_sms_notification("刷新报表(ID=#{report_id})缓存异常", backtrace.join("\n"), receivers)
    puts backtrace.join("\n")
  end

  namespace :cache do
    desc 'remove deprecated cache'
    task clean_deprecated: :environment do
      begin
        template_report_paths = Report.all.map do |report|
          format('%s/%s', report.template_id, report.report_id)
        end

        remove_deprecated_report_cache_paths('report', template_report_paths)
        remove_deprecated_report_cache_paths('report#zip', template_report_paths)
        remove_deprecated_report_cache_paths('report#audio', template_report_paths)
      rescue => e
        puts format('%s - %s', Time.now, e.message)
      end
    end

    desc 'make sure all groups report cache generated'
    task omit: :environment do
      include ::Template::InstanceMethods

      refresh_report_omit_groups(ENV['REPORT_ID'])
    end

    desc 'refresh all reports'
    task :refresh do
      Rake::Task['report:cache:_refresh_middleware'].invoke('refresh')
    end

    desc 'unrealtime reports'
    task :normal do
      Rake::Task['report:cache:_refresh_middleware'].invoke('normal')
    end

    desc 'realtime reports'
    task :realtime do
      Rake::Task['report:cache:_refresh_middleware'].invoke('realtime')
    end

    desc 'wastetime reports'
    task :wastetime do
      Rake::Task['report:cache:_refresh_middleware'].invoke('wastetime')
    end

    desc 'report ids'
    task report_ids: :environment do
      (ENV['REPORT_IDS'] || ENV['IDS'] || '').split(',').map(&:strip).compact.each_with_index do |report_id, index|
        refresh_report_data_cache_with_group_ids(report_id, REPORT_REDIS_KEY, (ENV['GROUP_IDS'] || "").split(",").map(&:to_i))
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
        puts "#{__FILE__}:#{__LINE__} - #{e.message}"
        exit
      end

      refresh_type = args.fetch(:refresh_type, 'unknow_refresh_type')
      config = {
        realtime: {
          title: '实时报表',
          pid: REPORT_CACHE_REALTIME_PID,
          status_key: REPORT_REALTIME_REDIS_KEY,
          sql: "refresh_type = '#{refresh_type}'"
        },
        normal: {
          title: '常规报表',
          pid: REPORT_CACHE_NORMAL_PID,
          status_key: REPORT_NORMAL_REDIS_KEY,
          sql: "refresh_type = '#{refresh_type}' or 1 = 1"
        },
        wastetime: {
          title: '耗时报表',
          pid: REPORT_CACHE_WASTETIME_PID,
          status_key: REPORT_WASTETIME_REDIS_KEY,
          sql: "refresh_type = '#{refresh_type}'"
        },
        refresh: {
          title: '所有报表',
          pid: REPORT_CACHE_REFRESH_PID,
          status_key: REPORT_REFRESH_REDIS_KEY,
          sql: %(1 = 1)
        }
      }
      config_hash      = config.fetch(refresh_type.to_sym, {})
      task_pid_file    = config_hash[:pid]
      redis_status_key = config_hash[:status_key]
      sql_condition    = config_hash[:sql]
      redis_format_key = REPORT_REDIS_KEY

      if ENV['DATABASE'].start_with?("saas_")
        redis_status_key = redis_status_key.sub("cache/", "#{ENV['DATABASE']}/cache/")
        task_pid_file = "#{ENV['DATABASE']}-#{task_pid_file}"
      else
        redis_status_key = redis_status_key.sub("cache/", "local/cache/")
        task_pid_file = "local-#{task_pid_file}"
      end

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
        redis_key = format(REPORT_REDIS_KEY, report.report_id)
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
