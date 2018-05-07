#encoding: utf-8

desc 'rake task process defender'
task task_defender: :environment do
  register Sinatra::Redis
  
  databases = Dir.glob(app_root_join("config/saas_*.yaml")).map do |path|
    File.basename(path, ".yaml")
  end.unshift("local")

  runtime_block 'rake task process defender' do
    databases.each do |database|
      saas_report_cache_realtime_pid  = format('%s_report_cache_realtime', database).freeze
      saas_report_cache_wastetime_pid = format('%s_report_cache_wastetime', database).freeze
      saas_report_cache_normal_pid    = format('%s_report_cache_normal', database).freeze
      saas_report_cache_refresh_pid   = format('%s_report_cache_refresh', database).freeze
      saas_report_realtime_redis_key  = format('cache/%s/report/realtime', database).freeze
      saas_report_wastetime_redis_key = format('cache/%s/report/wastetime', database).freeze
      saas_report_normal_redis_key    = format('cache/%s/report/normal', database).freeze
      saas_report_refresh_redis_key   = format('cache/%s/report/refresh', database).freeze

      rake_task_process_defender(saas_report_cache_realtime_pid, saas_report_realtime_redis_key, saas_report_realtime_redis_key)
      rake_task_process_defender(saas_report_cache_wastetime_pid, saas_report_wastetime_redis_key, saas_report_wastetime_redis_key)
      rake_task_process_defender(saas_report_cache_normal_pid, saas_report_normal_redis_key, saas_report_normal_redis_key)
      rake_task_process_defender(saas_report_cache_refresh_pid, saas_report_refresh_redis_key, saas_report_refresh_redis_key)
    end

    rake_task_process_defender(MOBILE_V2_REFRESH_PID, MOBILE_V2_REDIS_KEY, 'mobile:v2:refresh')
    rake_task_process_defender(BOOM_CHECK_PID, BOOM_CHECK_REDIS_KEY, 'boom:check')
    rake_task_process_defender(NOTIFY_DELIVER_PID, NOTIFY_DELIVER_REDIS_KEY, 'boom:notify_deliver')
    rake_task_process_defender(VISITED_LOGGER_PID, VISITED_REDIS_KEY, 'log:redis_to_mysql:visit')
    rake_task_process_defender(ACTION_LOGGER_PID, ACTION_REDIS_KEY, 'log:redis_to_mysql:action')
    rake_task_process_defender(SAAS_OMIT_REPORT_PID, SAAS_OMIT_REPORT_REDIS_KEY, 'saas_omit_report')
    rake_task_process_defender(SAAS_FISHNET_REPORT_PID, SAAS_FISHNET_REPORT_REDIS_KEY, 'saas_fishnet_report')
    rake_task_process_defender(SNAPSHOT_FISHNET_REPORT_PID, SNAPSHOT_FISHNET_REPORT_REDIS_KEY, 'snapshot_fishnet')
    rake_task_process_defender(SAAS_PROCEDURES_PID, SAAS_PROCEDURES_REDIS_KEY, 'saas_procedures')

    Rake::Task['task_killer'].invoke
  end
end

desc 'kill the task that pid not in tmp/pids'
task :task_killer do
  pids = Dir.glob(app_tmp_join('pids/*.pid')).map { |path| File.read(path).strip }
  skip_grep = %w(grep task_killer task_defender).map { |keyword| %(grep -v #{keyword}) }.join('|')
  task_pids = `/bin/ps aux | grep '\brake\b' | #{skip_grep}`.split(/\n/).map do |line|
    line.split(/\s+/).fetch(1, nil)
  end.compact

  unknown_pids = task_pids - pids
  unless unknown_pids.empty?
    `/bin/kill -KILL #{unknown_pids.join(' ')}`
    puts %(#{Time.now}: unkown rake process killed: #{unknown_pids})
  end
end

namespace :doctor do
  namespace :mysql do
    task state: :environment do
      begin
        ActiveRecord::Base.establish_connection
        version = ActiveRecord::Base.connection.execute("select version();").map(&:inspect).flatten.join
        puts "mysql(#{version}) connect successfully"
      rescue Exception => e
        puts "#{File.basename(__FILE__)}:#{__LINE__} - #{e.message}"
      end
    end

    task commands: :environment do
      config_hash = ActiveRecord::Base.connection_config
      mysql_port = config_hash[:port] || 3306
      puts "## enter:\n\nmysql -h#{config_hash[:host]} -u#{config_hash[:username]} -p#{config_hash[:password]} -P#{mysql_port} #{config_hash[:database]}"
      puts "\n## export:\n\nmysqldump -h#{config_hash[:host]} -u#{config_hash[:username]} -p#{config_hash[:password]} -P#{mysql_port} #{config_hash[:database]} > #{config_hash[:database]}-#{Time.now.strftime('%y%m%d%H%M%S')}.sql"
      puts "\n## import:\n\nmysql -h#{config_hash[:host]} -u#{config_hash[:username]} -p#{config_hash[:password]} -P#{mysql_port} #{config_hash[:database]} < your.sql"
      puts "\n## copydb:\n\nmysqldump -h#{config_hash[:host]} -u#{config_hash[:username]} -p#{config_hash[:password]} -P#{mysql_port} --add-drop-table #{config_hash[:database]} | mysql -h#{config_hash[:host]} -u#{config_hash[:username]} -p#{config_hash[:password]} to_database_name"
    end

    task sql_mode: :environment do
      puts ActiveRecord::Base.execute("select @@sql_mode").map(&:inspect).flatten.join
    end

    task export: :environment do
      config_hash = ActiveRecord::Base.connection_config

      table_names_without_data = %w(sys_action_logs sys_barcode_result)
      table_names = app_dependency_tables - table_names_without_data
      table_names.push('schema_migrations')
      puts "## tables without data:\n"
      puts %Q(mysqldump -h#{config_hash[:host]} -u#{config_hash[:username]} -p#{config_hash[:password]} -d --add-drop-table #{config_hash[:database]} #{table_names_without_data.join(' ')} > #{config_hash[:database]}-nodata-#{Time.now.strftime('%y%m%d%H%M%S')}.sql)
      puts "\n\n## tables with data:\n"
      puts %Q(mysqldump -h#{config_hash[:host]} -u#{config_hash[:username]} -p#{config_hash[:password]} #{config_hash[:database]} #{table_names.join(' ')} > #{config_hash[:database]}-data-#{Time.now.strftime('%y%m%d%H%M%S')}.sql)
    end
  end

  namespace :redis do
    task state: :environment do
      begin
        redis.ping
        puts 'redis ping successfully'
      rescue => e
        puts "#{File.basename(__FILE__)}:#{__LINE__} - #{e.message}"
      end
    end
  end

  namespace :os do
    task :date do
      current = `date "+%Y-%m-%d %H:%M:%S"`.strip
      time_zone = `date -R`.strip.match(/\+\d{4}/).to_s
      puts "#{time_zone == '+0800' ? '' : 'WARNGIN: '}date #{current} #{time_zone}"
    end
  end
end
