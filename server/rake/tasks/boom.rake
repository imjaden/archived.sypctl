# encoding: utf-8
require 'lib/utils/sms_sender'
require 'lib/utils/template_engine_checker'
namespace :boom do
  def check_setting_has_key?(keystr, delimit = '.')
    parts = keystr.split(delimit)
    instance = ::Setting
    has_key = true
    while has_key & p = parts.shift
      has_key = instance.has_key?(p)
      instance = instance.send(p) if has_key
    end
    has_key
  end

  desc 'check config/setting.yaml necessary keys'
  task setting: :environment do
    {
      '应用配置' => ['website.title', 'website.domain'],
      '友盟推送' => ['umeng.ios.app_key', 'umeng.ios.app_master_secret', 'umeng.android.app_key', 'umeng.android.app_master_secret'],
      '极验验证' => ['geetest.captcha_id', 'geetest.private_key'],
      '美联软通' => ['sms.username', 'sms.password', 'sms.apikey'],
      '七牛存储' => ['qiniu.bucket', 'qiniu.access_key', 'qiniu.secret_key', 'qiniu.out_link'],
      '邮件发送' => ['email.username', 'email.password'],
      '日志过滤' => ['action_log.white_list', 'action_log.black_list'],
      '进程管理' => ['unicorn.timeout', 'unicorn.worker_processes'],
      '缓存管理' => ['report_cache_thread.ignore', 'report_cache_thread.realtime', 'report_cache_thread.wastetime', 'report_cache_thread.normal'],
      '系统监控' => ['system_limit.disk', 'system_limit.memory'],
      '蒲公英'   => ['pgyer.api_key', 'pgyer.shortcut'],
      '永辉学院' => ['yh.api', 'yh.token'],
      'API 验证' => ['api_keys'],
      'SaaS 配置' => ['saas.public_image_path', 'saas.mysql_backup_path']
    }.each_pair do |key, array|
      not_exist_keys = array.find_all { |key_string| !check_setting_has_key?(key_string) }
      puts %(【#{key}】缺失下述字段:\n#{not_exist_keys.join("\n")}) unless not_exist_keys.empty?
    end
  end

  BOOM_CHECK_PID           = 'boom_check'.freeze
  BOOM_CHECK_REDIS_KEY     = 'boom/check/task'.freeze
  NOTIFY_DELIVER_PID       = 'notify_deliver'.freeze
  NOTIFY_DELIVER_REDIS_KEY = 'boom/notify/deliver'.freeze

  desc 'run all check process'
  task check: :environment do
    register Sinatra::Redis

    exit_when_redis_not_match(BOOM_CHECK_REDIS_KEY, 'status', 'running')
    update_redis_key_value(BOOM_CHECK_REDIS_KEY, 'status', 'running')
    generate_pid_file(BOOM_CHECK_PID)

    Rake::Task['boom:check_report'].invoke
    Rake::Task['boom:check_kpi'].invoke
    Rake::Task['boom:check_sys_tables'].invoke
    Rake::Task['boom:check_outer_link'].invoke

    delete_pid_file(BOOM_CHECK_PID)
    update_redis_key_value(BOOM_CHECK_REDIS_KEY, 'status', 'done')
  end

  desc 'send email or sms'
  task notify_deliver: :environment do
    register Sinatra::Redis

    exit_when_redis_not_match(NOTIFY_DELIVER_REDIS_KEY, 'status', 'running')
    update_redis_key_value(NOTIFY_DELIVER_REDIS_KEY, 'status', 'running')
    generate_pid_file(NOTIFY_DELIVER_PID)

    ::BangBoom.where(notify_mode: 'sms', send_state: 'wait').each do |record|
      if record.notify_level == 10
        content = %(#{record.title}，请及时登录后台修正(#{record.id})。)
      else
        content = %(#{record.description})
      end
      response = SMS.send_with_signature(record.receivers, content)
      record.update(send_state: 'done', send_result: response)
    end

    delete_pid_file(NOTIFY_DELIVER_PID)
    update_redis_key_value(NOTIFY_DELIVER_REDIS_KEY, 'status', 'done')
  end

  desc 'check_report skip develop report which id start with 99'
  task check_report: :environment do
    checker = Template::Engine::Checker.new
    condition = %(NOT(LEFT(report_id, 2) = 99 AND LENGTH(report_id) > 2) AND template_id != 5)
    booms = Report.where(condition).map do |report|
      error_count, info_list = checker.check_report(report)
      report.set_health_report(error_count, info_list)

      report.update_column(:health_value, error_count) unless report.health_value == error_count
      unless error_count.zero?
        info_text = info_list.map { |info| '- ' + info }.join("\n")
        <<-EOF.strip_heredoc + info_text
          《#{report.title}(#{report.report_id}/#{report.template_id})》
          检测到 #{error_count} 个异常：
        EOF
      end
    end.compact

    unless booms.empty?
      booms.unshift(%(扫描到#{booms.count} 支报表发现异常))
      ::BangBoom.create(
        title: booms.first,
        description: booms.join("\n"),
        notify_mode: 'sms',
        notify_level: 10,
        receivers: ::WConfig.fetch('sypc_000011')
      )
    end
  end

  desc 'check kpi id with report'
  task check_kpi: :environment do
    checker = Template::Engine::Checker.new
    condition = %(NOT(LEFT(kpi_id, 2) = 99 AND LENGTH(kpi_id) > 2))
    booms = KpiBase.where(condition).map do |kpi|
      error_count, info_list = checker.check_kpi(kpi)
      unless error_count.zero?
        info_text = info_list.map { |info| '- ' + info }.join("\n")
        <<-EOF.strip_heredoc + info_text
          《#{kpi.kpi_name}(#{kpi.kpi_id})》
          检测到 #{error_count} 个异常：
        EOF
      end
    end.compact

    unless booms.empty?
      booms.unshift(%(扫描到#{booms.count} 支仪表盘发现异常))
      ::BangBoom.create(
        title: booms.first,
        description: booms.join("\n"),
        notify_mode: 'sms',
        notify_level: 10,
        receivers: ::WConfig.fetch('sypc_000011')
      )
    end
  end

  desc 'check system tables exist'
  task check_sys_tables: :environment do
    table_names = app_dependency_tables
    connection = ActiveRecord::Base.connection
    unexist_tables = table_names - connection.data_sources

    unless unexist_tables.empty?
      text = unexist_tables.map { |t| '- ' + t }.join("\n")
      description = <<-EOF.strip_heredoc + text
        扫描到 #{unexist_tables.count} 支应用数据表不存在，请及时修复：
      EOF
      ::BangBoom.create(
        title: %(应用表被删除),
        description: description,
        notify_mode: 'sms',
        notify_level: 10,
        receivers: ::WConfig.fetch('sypc_000012')
      )
    end
  end

  def object_ids_without_role(object_type)
    RoleResource.where(obj_type: object_type).map(&:obj_id).uniq
  end

  def check_out_link_response(object_type, klass_name, type_name)
    bad_messages = []
    klass = klass_name.camelize.constantize
    object_ids_without_role(object_type).each do |id|
      record = klass.find_by(id: id)
      next if record.blank?

      if record.report_id.blank? && record.url_path.blank?
        bad_messages.push(%(#{type_name}(#{record.id}) report_id/url_path 不可同时为空))
      elsif record.report_id.present?
        bad_messages.push("配置的报表不存在 report_id=#{record.report_id}") unless ::Report.find_by(report_id: record.report_id)
      elsif record.url_path.present?
        begin
          params = { browser: 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_2_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Mobile/13D15' }
          response = HTTParty.get record.url_path, body: params
          response_code = response.code
        rescue => e
          puts e.message
          puts e.backtrace.select { |info| info.start_with?(Dir.pwd) }
          # fixed: get pdf link response `bad URI(is not URI?)`
          response_code = 200
        ensure
          bad_messages.push(%(#{type_name}(#{record.id}) - #{record.url_path} 响应值: #{response_code})) if response_code != 200
        end
      end
    end
    bad_messages
  end

  desc 'check app/analyse outer link response is 200'
  task check_outer_link: :environment do
    bad_messages = []
    bad_messages << check_out_link_response(OBJ_TYPE_ANALYSE, 'Analyse', '分析')
    bad_messages << check_out_link_response(OBJ_TYPE_APP, 'App', '应用')
    bad_messages.flatten!

    unless bad_messages.empty?
      ::BangBoom.create(
        title: %(分析、应用表存在脏数据),
        description: bad_messages.join("\n"),
        notify_mode: 'sms',
        notify_level: 10,
        receivers: ::WConfig.fetch('sypc_000011')
      )
    end
  end

  def query_last_end_time(conn)
    sql_string = 'select max(end_time) as last_end_time from procedurelog where error_msg is not null;'
    result = conn.execute(sql_string)
    result.to_a.flatten.first || Time.now.strftime('%Y-%m-%d %H:%M:%S')
  end

  desc 'mysql state'
  task mysql: :environment do
    conn = ActiveRecord::Base.connection
    booms = []

    sql_string = <<-EOF
      select concat('kill ', id, ',') as command, db, info
        from information_schema.processlist;
    EOF
    titles = %w(command db info)
    booms.push query_sql(conn, sql_string, titles).flatten.map(&:to_s).join("\n")

    `/bin/mkdir -p tmp/booms`
    temp_path = app_tmp_join('booms/procedurelog.end_time')
    last_end_time = File.exist?(temp_path) ? File.read(temp_path).strip : query_last_end_time(conn)

    sql_string = <<-EOF
      select procedure_name, error_msg
        from procedurelog
      where error_msg is not null
        and end_time > '#{last_end_time}';
    EOF

    titles = %w(procedure error)
    booms.push query_sql(conn, sql_string, titles).flatten.map(&:to_s).join("\n")
    File.open(temp_path, 'w:utf-8') { |file| file.puts query_last_end_time(conn) }

    unless booms.empty?
      ::BangBoom.create(
        title: %(分析、应用表存在脏数据),
        description: bad_messages.join("\n"),
        notify_mode: 'sms',
        notify_level: 10,
        receivers: ::WConfig.fetch('sypc_000011')
      )
    end
  end

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

    model_path = app_tmp_path(%(rb/#{table_name}.rb))
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

  task report: :environment do
    Report.find_each(batch_size: 100).each do |report|
      if [2, 4].include?(report.template_id)
        tables = report.configuration_tables
        empty_count = tables.select { |table_name| class_get(table_name).count.zero? }.count
        puts format("%-20s | %-5d | %-5d | %-5d | %-5d", report.title, report.report_id, report.template_id, tables.count, empty_count)
      end
    end
  end

  task etl: :environment do
    records, data_exception_messages, code_exception_messages = [], [], []
    begin
      records = ActiveRecord::Base.connection.exec_query("call pro_query_reports_etl();").to_ary
      ActiveRecord::Base.connection.reconnect!
    rescue => e
      puts "#{__FILE__}:#{__LINE__} - #{e.message}"
      puts e.backtrace.select { |info| info.start_with?(Dir.pwd) }
    end

    # 0. 所有约束值 <= 0 时则跳过
    # 1. kpi 刷新频率监控
    # 2. kpi 刷新耗时监控
    # 3. etl 刷新频率监控
    # 4. etl 刷新耗时监控
    # 5. cache 与 etl 间隔时间监控
    # 6. cache 执行时间监控
    records.each do |hsh|
      begin
        constraint = ReportCacheRefreshConstraint.fetch(hsh['report_id'])
        hsh['kpi_begin_time']        ||= Time.now
        hsh['kpi_end_time']          ||= Time.now
        hsh['etl_begin_time']        ||= Time.now
        hsh['etl_end_time']          ||= Time.now
        hsh['cache_begin_time']      ||= Time.now
        hsh['cache_end_time']        ||= Time.now
        constraint.etl_refresh_limit ||= 60*60*24*30
        constraint.etl_execute_limit ||= 60*60*2

        # 1. kpi 刷新频率监控
        if constraint.kpi_refresh_limit > 0 && (Time.now - hsh['kpi_begin_time']) >= constraint.kpi_refresh_limit
          data_exception_messages << "#{hsh['report_title']}, #{hsh['report_id']}/#{hsh['template_id']}, KPI 刷新频率异常，最近刷新时间：#{hsh['kpi_begin_time']}, 距今 #{Time.now - hsh['kpi_begin_time']}s, 大于配置值：#{constraint.kpi_refresh_limit}s"
        end

        # 2. kpi 刷新耗时监控
        hsh['kpi_end_time'] = Time.now if hsh['kpi_end_time'] < hsh['kpi_begin_time']
        if constraint.kpi_execute_limit > 0 && (hsh['kpi_end_time'] - hsh['kpi_begin_time']) > constraint.kpi_execute_limit
          data_exception_messages << "#{hsh['report_title']}, #{hsh['report_id']}/#{hsh['template_id']}, KPI 刷新耗时异常，开始时间：#{hsh['kpi_begin_time']}, 结束时间：#{hsh['kpi_end_time']}, 刷新耗时：#{hsh['kpi_end_time'] - hsh['kpi_begin_time']}s, 大于配置值：#{constraint.kpi_execute_limit}s"
        end

        # 3. etl 刷新频率监控
        if constraint.etl_refresh_limit > 0 && (Time.now - hsh['etl_begin_time']) >= constraint.etl_refresh_limit
          data_exception_messages << "#{hsh['report_title']}, #{hsh['report_id']}/#{hsh['template_id']}, ETL 刷新频率异常，最近刷新时间：#{hsh['etl_begin_time']}, 距今 #{Time.now - hsh['etl_begin_time']}s, 大于配置值：#{constraint.etl_refresh_limit}s"
        end

        # 4. etl 刷新耗时监控
        hsh['etl_end_time'] = Time.now if hsh['etl_end_time'] < hsh['etl_begin_time']
        if constraint.etl_execute_limit > 0 && (hsh['etl_end_time'] - hsh['etl_begin_time']) > constraint.etl_execute_limit
          data_exception_messages << "#{hsh['report_title']}, #{hsh['report_id']}/#{hsh['template_id']}, ETL 刷新耗时异常，开始时间：#{hsh['etl_begin_time']}, 结束时间：#{hsh['etl_end_time']}, 刷新耗时：#{hsh['etl_end_time'] - hsh['etl_begin_time']}s, 大于配置值：#{constraint.etl_execute_limit}s"
        end

        # 5. cache 与 etl 间隔时间监控
        hsh['cache_begin_time'] = Time.now if hsh['cache_begin_time'] < hsh['etl_end_time']
        if constraint.cache_refresh_limit > 0 && (hsh['cache_begin_time'] - hsh['etl_end_time']) > constraint.cache_refresh_limit
          data_exception_messages << "#{hsh['report_title']}, #{hsh['report_id']}/#{hsh['template_id']}, Cache 刷新间隔异常，最近刷新时间：#{hsh['cache_begin_time']}, 距今 #{Time.now - hsh['cache_begin_time']}s, 大于配置值：#{constraint.cache_refresh_limit}s"
        end

        # # 6. cache 执行时间监控
        # hsh['cache_end_time'] = Time.now if hsh['cache_end_time'] < hsh['cache_begin_time']
        # if constraint.cache_execute_limit > 0 && (hsh['cache_end_time'] - hsh['cache_begin_time']) > constraint.cache_execute_limit
        #   data_exception_messages << "#{hsh['report_title']}, #{hsh['report_id']}/#{hsh['template_id']}, Cache 刷新耗时异常，开始时间：#{hsh['cache_begin_time']}, 结束时间：#{hsh['cache_end_time']}, 刷新耗时：#{hsh['cache_end_time'] - hsh['cache_begin_time']}s, 大于配置值：#{constraint.cache_execute_limit}s"
        # end
      rescue => e
        exception_backtraces = ["#{__FILE__}:#{__LINE__} - #{e.message}"]
        exception_backtraces += e.backtrace.select { |info| info.start_with?(Dir.pwd) }
        code_exception_messages.push(exception_backtraces.join("\n"))
      end
    end

    unless data_exception_messages.empty?
      data_exception_receivers = ::WConfig.fetch('sypc_000011')
      exception_title = "ETL 监控进程发现 #{data_exception_messages.length} 个数据异常"
      ::BangBoom.create_with_sms_notification(exception_title, data_exception_messages.join("\n"), data_exception_receivers)
    end

    unless code_exception_messages.empty?
      code_exception_receivers = ::WConfig.fetch('sypc_000012')
      exception_title = "ETL 监控进程发现 #{code_exception_messages.length} 个代码异常"
      ::BangBoom.create_with_sms_notification(exception_title, code_exception_messages.join("\n"), code_exception_receivers)
    end
  end
end
