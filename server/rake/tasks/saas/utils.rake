# encoding: utf-8
require 'fileutils'

namespace :saas do
  task yaml: :environment do
    start_time, list = Time.now, []
    SupDataSource.all.each do |record|
      next if record.data_source_name == 'saas_main_db'
      next unless config = saas_data_source_convert_to_hash(record)

      mysql_version, mysql_date = '', ''
      begin
        ActiveRecord::Base.establish_connection(config)
        mysql_version = ActiveRecord::Base.connection.execute("select version();").map(&:flatten).flatten.join
        mysql_date = ActiveRecord::Base.connection.execute("select now();").map(&:flatten).flatten.join

        # _#{config[:host].gsub('.', '-')}
        yaml_path = app_root_join("config/#{config[:database]}.yaml")
        yaml_temp = "#{yaml_path}.temp"
        File.open(yaml_temp, "w:utf-8") do |file|
          file.puts <<-YAML.strip_heredoc
            default: &default
              adapter: 'mysql2'
              encoding: 'utf8'
              pool: 8
              host: '#{config[:host]}'
              port: '#{config[:port]}'
              username: '#{config[:username]}'
              password: '#{config[:password]}'
              flags: ['MULTI_STATEMENTS']

            production:
              <<: *default
              database: '#{config[:database]}'

            development:
              <<: *default
              database: '#{config[:database]}'

            test:
              <<: *default
              database: '#{config[:database]}'
          YAML
        end
        File.rename(yaml_temp, yaml_path)
        list << [config[:host], config[:database], mysql_version, mysql_date, 'success']
      rescue => e
        list << [config[:host], config[:database], mysql_version, mysql_date, e.message]
      end
    end
    puts "#{start_time} - YAML 自动生成："
    puts Terminal::Table.new(headings: ['主机', '数据库', '版本', '时区', '生成状态'], rows: list)
    puts "#{Time.now} - 耗时：#{Time.now - start_time}s"
  end

  SAAS_OMIT_REPORT_PID       = 'saas_omit_report'.freeze
  SAAS_OMIT_REPORT_REDIS_KEY = 'saas_omit_report'.freeze
  task omit: :environment do
    register Sinatra::Redis

    exit_when_redis_not_match(SAAS_OMIT_REPORT_REDIS_KEY, 'status', 'running')
    update_redis_key_value(SAAS_OMIT_REPORT_REDIS_KEY, 'status', 'running')
    generate_pid_file(SAAS_OMIT_REPORT_PID, Process.pid)

    SupDataSource.all.each do |record|
      next if record.data_source_name == 'saas_main_db'
      next unless config = saas_data_source_convert_to_hash(record)

      begin
        ActiveRecord::Base.establish_connection(config)
        report_sql = "select template_id, report_id, count(distinct group_id) as group_count from sys_group_reports where template_id in (11, 12) group by report_id, template_id;"
        ActiveRecord::Base.connection.exec_query(report_sql).to_ary.each do |report_hash|
          timestamp_sql = "select timestamp from sys_timestamp_manager where obj_type = 'report#data' and obj_id = #{report_hash['report_id']} limit 1;"
          timestamp_hash = ActiveRecord::Base.connection.exec_query(timestamp_sql).to_ary.first
          cmd_result = 0
          begin
            report_cache_path = "#{ENV['APP_ROOT_PATH']}/tmp/#{config[:database]}/cache/report#json/11/#{report_hash['report_id']}"
            `mkdir -p #{report_cache_path}`
            cmd = "ls #{report_cache_path} | wc -l"
            cmd_result = run_command(cmd)[1].strip
          rescue => e
            puts "#{__FILE__}:#{__LINE__} - #{e.message}"
            cmd_result = -1
          end

          if cmd_result.to_i >= 0 && report_hash["group_count"].to_i > cmd_result.to_i
            redis_key = REPORT_NORMAL_REDIS_KEY.sub("cache/", "#{config[:database]}/cache/")

            if (redis.exists(redis_key) && redis.hget(redis_key, "status") == "running")
              puts [config[:database], report_hash["group_count"], cmd_result, "running, then skip"].join(",")
              next
            end
            
            bundle_command = "bundle exec rake report:cache:omit DATABASE=#{config[:database]} REPORT_ID=#{report_hash['report_id']} >> log/crontab/report_cache_omit.log 2>&1"
            puts bundle_command
            `#{bundle_command}`
          end
        end
      rescue => e
        puts "#{__FILE__}:#{__LINE__} - #{e.message}"
      end
    end
      
    update_redis_key_value(SAAS_OMIT_REPORT_REDIS_KEY, 'status', 'done')
    delete_pid_file(SAAS_OMIT_REPORT_PID)
  end

  SAAS_FISHNET_REPORT_PID       = 'saas_fishnet_report'.freeze
  SAAS_FISHNET_REPORT_REDIS_KEY = 'saas_fishnet_report'.freeze

  task fishnet: :environment do
    register Sinatra::Redis

    exit_when_redis_not_match(SAAS_FISHNET_REPORT_REDIS_KEY, 'status', 'running')
    update_redis_key_value(SAAS_FISHNET_REPORT_REDIS_KEY, 'status', 'running')
    generate_pid_file(SAAS_FISHNET_REPORT_PID, Process.pid)

    Dir.glob(app_tmp_join('fishnet/*.*')) do |path|
      database, report_id = File.basename(path).to_s.split(".")
      group_ids = IO.readlines(path).map(&:strip).uniq.compact.reject(&:empty?).join(",")

      FileUtils.rm_f(path)
      bundle_command = "bundle exec rake report:cache:report_ids DATABASE=#{database} REPORT_IDS=#{report_id} GROUP_IDS=#{group_ids} >> log/crontab/saas_fishnet.log 2>&1"
      puts bundle_command
      `#{bundle_command}`
    end

    update_redis_key_value(SAAS_FISHNET_REPORT_REDIS_KEY, 'status', 'done')
    delete_pid_file(SAAS_FISHNET_REPORT_PID)
  end

  task reports: :environment do
    action_mode = ENV['ACTION_MODE'] || 'nothing'
    start_time, list = Time.now, []
    SupDataSource.all.each do |record|
      next if record.data_source_name == 'saas_main_db'
      next unless config = saas_data_source_convert_to_hash(record)

      begin
        ActiveRecord::Base.establish_connection(config)
        report_sql = "select template_id, report_id, count(distinct group_id) as group_count from sys_group_reports where template_id in (11, 12) group by report_id, template_id;"
        ActiveRecord::Base.connection.exec_query(report_sql).to_ary.each do |report_hash|
          timestamp_sql = "select date_format(timestamp, '%Y-%m-%d %H:%i:%s') as timestamp from sys_timestamp_manager where obj_type = 'report#data' and obj_id = #{report_hash['report_id']} limit 1;"
          timestamp_hash = ActiveRecord::Base.connection.exec_query(timestamp_sql).to_ary.first
          report_cache_path = "#{ENV['APP_ROOT_PATH']}/tmp/#{config[:database]}/cache/report#json/11/#{report_hash['report_id']}"
          cached_file_count, expired_cached_file_count = 0, 0
          begin
            cached_file_count = run_command("ls #{report_cache_path} | wc -l")[1].strip
          rescue => e
            cached_file_count = e.message
          end

          begin
            expired_cached_file_count = run_command("find #{report_cache_path} -type f -not -newermt '#{timestamp_hash['timestamp']}' | wc -l")[1].strip
          rescue => e
            expired_cached_file_count = e.message
          end

          if action_mode == 'clean_expired_cached_file'
            begin
              run_command("find #{report_cache_path} -type f -not -newermt '#{timestamp_hash['timestamp']}' -exec rm {} \\;")
            rescue => e
              puts "#{__FILE__}:#{__LINE__} - #{e.message}"
            end
          end
          list << [config[:host], config[:database], report_hash["template_id"], report_hash["report_id"], timestamp_hash['timestamp'], report_hash["group_count"], cached_file_count, expired_cached_file_count, Time.now.strftime("%Y-%m-%d %H:%M:%S")]
        end
      rescue => e
        list << [config[:host], config[:database], '', '', '', '', '', e.message, Time.now.strftime("%Y-%m-%d %H:%M:%S")]
      end
    end
    puts "#{start_time} - 清理过期缓存文件：" if action_mode == 'clean_expored_cached_file'
    data = {headings: ['主机', '数据库', '模板', '报表', '时间戳', '群组数据', '缓存数量', '过期缓存', '执行时间'], rows: list, timestamp: Time.now}
    puts Terminal::Table.new(data)
    puts "#{Time.now} - 耗时：#{Time.now - start_time}s"

    state_path = File.join(ENV['APP_ROOT_PATH'], 'tmp/saas_state')
    FileUtils.mkdir_p(state_path) unless File.exists?(state_path)
    File.open(File.join(state_path, 'saas_report_cache_state.json'), 'w:utf-8') do |file|
      file.puts(data.to_json)
    end
  end

  SAAS_PROCEDURES_PID       = 'saas_procedures'.freeze
  SAAS_PROCEDURES_REDIS_KEY = 'saas_procedures'.freeze
  task procedures: :environment do
    register Sinatra::Redis

    exit_when_redis_not_match(SAAS_PROCEDURES_REDIS_KEY, 'status', 'running')

    timestamp = (SupProcedure.maximum(:modify_time) || Time.now).strftime("%Y-%m-%d %H:%M:%S")
    exit_when_redis_not_match(SAAS_PROCEDURES_REDIS_KEY, 'updated_at', timestamp)
    update_redis_key_value(SAAS_PROCEDURES_REDIS_KEY, 'status', 'running')
    generate_pid_file(SAAS_PROCEDURES_PID, Process.pid)

    state_path = File.join(ENV['APP_ROOT_PATH'], 'tmp/saas_state')
    FileUtils.mkdir_p(state_path) unless File.exists?(state_path)
    procedures_path = File.join(state_path, 'procedures')
    FileUtils.mkdir_p(procedures_path) unless File.exists?(procedures_path)

    procedures = SupProcedure.where("procontent is not null and procode is not null").to_ary

    procedures.each do |record|
      procedure_path = File.join(procedures_path, "#{record.procode}.sql")
      File.open(procedure_path, 'w:utf-8') { |file| file.puts(record.procontent) }
    end

    start_time, list = Time.now, []
    SupDataSource.all.each do |record|
      # next if record.data_source_name == 'saas_main_db'
      config = saas_data_source_convert_to_hash(record)

      execute_success, execute_failed = [], []
      procedures.each do |record|
        procedure_path = File.join(procedures_path, "#{record.procode}.sql")

        begin
          sql_command = saas_import_sql_file_command(procedure_path, config)
          cmd_state   = run_command(sql_command).flatten.join
          execute_success.push(record.procode)
        rescue => e
          exception_path = File.join(procedures_path, "#{record.procode}.exception")
          File.open(exception_path, 'w:utf-8') { |file| file.puts(e.backtrace.unshift(e.message).join("\n")) }
          execute_failed.push(exception_path)
        end
      end

      list << [config[:host], config[:database], timestamp, procedures.count, execute_success.count, execute_failed.count, Time.now.strftime("%Y-%m-%d %H:%M:%S")]
    end

    data = {headings: ['主机', '数据库', '更新时间', '存储过程', '成功', '失败', '执行时间'], rows: list, timestamp: Time.now}
    puts Terminal::Table.new(data)
    puts "#{Time.now} - 耗时：#{Time.now - start_time}s"
    File.open(File.join(state_path, 'saas_procedures_state.json'), 'w:utf-8') { |file| file.puts(data.to_json) }

    update_redis_key_value(SAAS_PROCEDURES_REDIS_KEY, 'updated_at', timestamp)
    update_redis_key_value(SAAS_PROCEDURES_REDIS_KEY, 'status', 'done')
    delete_pid_file(SAAS_PROCEDURES_PID)
  end
end