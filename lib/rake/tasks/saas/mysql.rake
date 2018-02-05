# encoding: utf-8
require 'fileutils'

namespace :saas do
  namespace :mysql do

    desc 'DATABASE=saas_main_db bundle exec rake saas:mysql:status'
    task status: :environment do
      register Sinatra::Redis

      start_time, list = Time.now, []
      list = SupDataSource.all.map do |record|
        config = saas_data_source_convert_to_hash(record)
        begin
          ActiveRecord::Base.establish_connection(config)
          version = ActiveRecord::Base.connection.execute("select version();").map(&:inspect).flatten.join
        rescue => e
          version = e.message
        end
        [config[:host], config[:database], version, Time.now.strftime("%Y-%m-%d %H:%M:%S")]
      end

      data = {headings: ['主机', '数据库', '版本', '执行时间'], rows: list, timestamp: Time.now}
      puts Terminal::Table.new(data)
      puts "#{Time.now} - 耗时：#{Time.now - start_time}s"
    end

    desc 'DATABASE=saas_main_db bundle exec rake saas:mysql:sys_tables'
    task sys_tables: :environment do
      unless File.exists?(Setting.saas.mysql_backup_path)
        puts "Setting.saas.mysql_backup_path not exist:\n#{Setting.saas.mysql_backup_path}"
        exit
      end

      sup_tables = %w(sup_api_code sup_application sup_application_company sup_application_datasource sup_company sup_company_source sup_data_source sup_execute_sql sup_procedure sup_route_report) # sup_user sup_user_application sup_user_company)
      ignore_tables = %w(sys_action_logs sys_callback_action_logs sys_bang_booms sys_barcode_result sys_visit_logs sys_report_cache_action_logs sys_message_center  sys_push_messages)
      backup_tables = app_dependency_tables - ignore_tables + sup_tables
      
      list = SupDataSource.all.map do |record|
        config = saas_data_source_convert_to_hash(record)
        mysql_backup_path = File.join(Setting.saas.mysql_backup_path, config[:host], config[:database], Time.now.strftime("%y%m%d"))
        FileUtils.mkdir_p(mysql_backup_path) unless File.exists?(mysql_backup_path)
        timestamp = Time.now.strftime("%y%m%d%H%M%S")

        begin
          ActiveRecord::Base.establish_connection(config)
          query_sys_and_sup_tables_sql = "select distinct ist.table_name as table_name from information_schema.tables as ist where ist.table_schema = '#{config[:database]}' and (ist.table_name like 'sys_%' or ist.table_name like 'sup_%');"
          sys_and_sup_tables = ActiveRecord::Base.connection.exec_query(query_sys_and_sup_tables_sql).rows.flatten
          exists_backup_tables = backup_tables & sys_and_sup_tables
          saas_mysqldump_sys_tables(mysql_backup_path, config, exists_backup_tables, timestamp)
        rescue => e
          version = e.message
          File.open("#{mysql_backup_path}/#{timestamp}-failed.log", "w:utf-8") { |file| file.write("\n#{Time.now}: #{e.message}\n") }
        end
      end
    end

    task backup: :environment do
    end

    task yaml: :environemnt do
    end
  end
end