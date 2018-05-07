# encoding: utf-8
require 'lib/utils/sms_sender'
require 'lib/utils/simple_system_monitor.rb'
namespace :system do
  namespace :report do
    namespace :procedure do
      task refresh_by_hour: :environment do
        begin
          pro_names = ActiveRecord::Base.connection.exec_query("show procedure status;").to_ary
            .map { |hsh| hsh['Name'] }
            .select { |pro_name| pro_name.include?("pro_refresh_by_hour") }
          
          pro_names.each do |pro_name|
            execute_sql = "call #{pro_name}();"
            puts "#{Time.now}: #{execute_sql}"
            records = ActiveRecord::Base.connection.execute(execute_sql)
            ActiveRecord::Base.connection.reconnect!
          end
        rescue => e
          puts e.message
          puts e.backtrace.select { |info| info.start_with?(Dir.pwd) }
        end
      end
      
      task refresh_by_day: :environment do
        begin
          pro_names = ActiveRecord::Base.connection.exec_query("show procedure status;").to_ary
            .map { |hsh| hsh['Name'] }
            .select { |pro_name| pro_name.include?("pro_refresh_by_day") }
          
          pro_names.each do |pro_name|
            execute_sql = "call #{pro_name}();"
            puts "#{Time.now}: #{execute_sql}"
            records = ActiveRecord::Base.connection.execute(execute_sql)
            ActiveRecord::Base.connection.reconnect!
          end
        rescue => e
          puts e.message
          puts e.backtrace.select { |info| info.start_with?(Dir.pwd) }
        end
      end
    end
  end

  desc 'system monitor list'
  task :monitor do
    begin
      Rake::Task['system:mem_and_disk'].invoke
      Rake::Task['system:table_id_autoincrement'].invoke
      # Rake::Task['system:report_timestamp_out24_hours'].invoke
      #Rake::Task['system:report_introspect'].invoke
    rescue => exception
      include ::Mail::Methods
      send_rake_crashed_email(exception, 'system:monitor', __FILE__, __LINE__)
    end
  end

  task table_id_autoincrement: :environment do
    config = ActiveRecord::Base.connection_config
    sql_command =<<-EOF
      select table_name
        from information_schema.columns as isc
       where isc.column_name = 'ID'
         and isc.table_schema = '#{config[:database]}'
         and table_name like 'sys_%'
         and extra not like '%auto_increment%'
    EOF
    tables = ActiveRecord::Base.connection.execute(sql_command).map(&:inspect).flatten
    unless tables.empty?
      ::BangBoom.create_with_sms_notification("#{tables.length}支数据表ID无自增属性", tables.join(', '), ::WConfig.fetch('sypc_000011'))
    end

    begin
      records = ActiveRecord::Base.connection.exec_query("call #{parmas[:procedure]}();").to_ary
      ActiveRecord::Base.connection.reconnect!
    rescue => e
      puts e.message
      puts e.backtrace.select { |info| info.start_with?(Dir.pwd) }
    end
  end

  task report_timestamp_out24_hours: :environment do
    sql_command =<<-EOF
      select
          str.title        as '报表标题'
        , str.report_id    as '报表ID'
        , stm.timestamp    as '缓存时间戳'
        , timestampdiff(SECOND, date_format(stm.timestamp, '%Y-%m-%d %H:%i:%s'), date_format(now(), '%Y-%m-%d %H:%i:%s')) /60/60 as distance
      from sys_template_reports as str
      left join sys_timestamp_manager as stm on str.report_id = stm.obj_id
      where stm.obj_type = 'report#data' and timestampdiff(SECOND, date_format(stm.timestamp, '%Y-%m-%d %H:%i:%s'), date_format(now(), '%Y-%m-%d %H:%i:%s')) /60/60 > 24
      order by stm.timestamp desc
    EOF
    tables = ActiveRecord::Base.connection.execute(sql_command).map { |array| array.join(", ") }
    unless tables.empty?
      ::BangBoom.create_with_sms_notification("#{tables.length}支报表超出24小时未刷新", tables.join("\n"), ::WConfig.fetch('sypc_000011'))
    end
  end

  desc 'report introspect'
  task report_introspect: :environment do
    register Sinatra::Redis

    booms = []
    ::RoleResource.where(obj_type: OBJ_TYPE_KPI).pluck('distinct obj_id').each do |kpi_id|
      unless kpi = ::KpiBase.find_by(kpi_id: kpi_id)
        booms.push(format('权限表中的仪表盘(%s) 不存在', kpi_id))
        next
      end

      kpi_name = format('%s(%s)[%s]', kpi.kpi_name, kpi.kpi_id, kpi.updated_at)
      booms.push(kpi_name + ' link 未设置') if kpi.link.blank?

      redis_key = format('cache/report/%s', kpi.link)
      updated_at = redis.hget(redis_key, 'updated_at')
      if kpi.updated_at.to_s == updated_at
        report = ::Report.find_by(report_id: kpi.link)
        if report
          booms.push(kpi_name + ' file_cache_timestamp 未匹配') if report.file_cache_timestamp != kpi.updated_at
        else
          booms.push(kpi_name + ' 未创建报表')
        end
      elsif kpi.kpi_name.include?('实时') && (Time.now - kpi.updated_at)/60 > 30
        booms.push(kpi_name + ' 实时报表刷新不及时')
      # elsif !kpi.kpi_name.include?('实时') && (Time.now - kpi.updated_at)/60 > 60
      #  booms.push(kpi_name + ' 非实时报表刷新不及时')
      end
    end

    unless booms.empty?
      boom = ::BangBoom.create(title: %(报表刷新异常), description: booms.join("\n"))
      content = %(报表刷新异常，请登录后台查看详情[#{boom.id}])
      response = ::SMS.send_with_signature(::WConfig.fetch('sypc_000011'), content)
      puts %(#{Time.now} - to: #{::WConfig.fetch('sypc_000011')})
      puts %(#{Time.now} - sms: #{content})
      puts %(#{Time.now} - state: #{response.inspect})
    end
  end

  desc 'mem/disk monitor'
  task mem_and_disk: :environment do
    report = ::SimpleSystem::Monitor.report
    mem_used = report.fetch(:mem, 0)
    disk_used = report.fetch(:disk, 0)

    crontab_path = %(#{ENV['APP_ROOT_PATH']}/log/crontab/)
    `mkdir -p #{crontab_path}`
    log_path = %(#{crontab_path}/system_monitor_report.log)

    report_data = read_json_guard(log_path, [])
    report_data.push(report)
    File.open(log_path, 'w:utf-8') { |file| file.puts(report_data.to_json) }

    if mem_used >= ::Setting.system_limit.memory || disk_used >= ::Setting.system_limit.disk
      content = %(内存(#{mem_used})或磁盘(#{disk_used})越过阀值，会影响服务正常运行)
      boom = ::BangBoom.create(title: %(系统预警), description: content)
      response = ::SMS.send_with_signature(::WConfig.fetch('sypc_000014'), content + %([#{boom.id}]))
      puts %(#{Time.now} - to: #{::WConfig.fetch('sypc_000014')})
      puts %(#{Time.now} - sms: #{content})
      puts %(#{Time.now} - state: #{response.inspect})
    end
  end

  desc 'reset redis user device state with mysql data'
  task user_device_state: :environment do
    register Sinatra::Redis

    UserDevice.all.each do |user_device|
      redis_state_key = %(/user_device/#{user_device.id}/state)
      redis.set(redis_state_key, user_device.state ? '1' : '0');
      puts %(#{redis_state_key} - #{redis.get(redis_state_key)})
    end
  end

  desc 'check sys_barcode_result index(barcode2, area_name#desc2)'
  task table_index_daemon: :environment do
    con = ActiveRecord::Base.connection

    table_index_daemon(con, :sys_users, [:user_num], {unique: true})
    table_index_daemon(con, :sys_devices, [:platform, :uuid])
    table_index_daemon(con, :sys_kpi_datas, [:group_id])
    table_index_daemon(con, :sys_website_config, [:keyname, :uuid])

    con.execute("ANALYZE TABLE sys_users;")
    con.execute("ANALYZE TABLE sys_devices;")
    con.execute("ANALYZE TABLE sys_kpi_datas;")
    con.execute("ANALYZE TABLE sys_website_config;")
  end

  desc 'update sys_group_reports'
  task update_group_reports: :environment do
    class DBConf < Settingslogic
      source File.absolute_path('./config/database.yaml') # %(#{ENV['APP_ROOT_PATH']}/config/database.yaml')
      namespace ENV['RACK_ENV']
      load!
    end unless defined?(DBConf)

    ActiveRecord::Base.establish_connection(
      adapter: DBConf.adapter,
      host: DBConf.host,
      username: DBConf.username,
      password: DBConf.password,
      database: DBConf.database
    )
    runtime_block_within_thread -1, 'update table sys_group_reports' do
      ActiveRecord::Base.connection.execute('truncate table sys_group_reports;')
      ActiveRecord::Base.connection.execute <<-EOF.strip_heredoc
          insert into sys_group_reports(group_id, report_id, template_id, created_at, updated_at) \
          select \
          t3.group_id \
          ,t1.obj_id as reoprt_id \
          ,t4.template_id \
          ,now() as created_at \
          ,now() as updated_at \
          from sys_role_resources t1 \
          left join sys_user_roles t2 on t1.role_id = t2.role_id \
          left join sys_user_groups t3 on t2.user_id = t3.user_id \
          inner join sys_template_reports t4 on t4.report_id = t1.obj_id \
          where t1.obj_type=1 and t3.group_id is not null \
          group by t3.group_id,t1.obj_id;
      EOF
    end
  end

  def table_indexs(con, table_name)
    sql_command = format('show index from %s;', table_name)
    temp_array = con.execute(sql_command).to_a.transpose.fetch(4, [])
    temp_array + temp_array.map(&:to_sym)
  end


  def table_index_daemon(con, table_name, indexs, options = {})
    current_indexs = table_indexs(con, table_name)
    return if (indexs & current_indexs) == indexs

    indexs -= current_indexs
    puts format('alter table %s add index %s', table_name, indexs)
    con.add_index(table_name, indexs, options)
  end

  def read_json_guard(json_path, default_return = [])
    return default_return unless File.exist?(json_path)

    json_hash = JSON.parse(IO.read(json_path))
    return default_return unless json_hash.is_a?(Array)
    json_hash
  rescue
    File.delete(json_path) if File.exist?(json_path)
    default_return
  end
end
