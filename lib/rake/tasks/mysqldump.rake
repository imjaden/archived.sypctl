# encoding: utf-8
namespace :mysqldump do
  def app_table_list
    Dir.glob(%(#{Dir.pwd}/app/models/*.rb)).map do |filepath|
      content = IO.read(filepath)
      content.scan(/self\.table_name\s+=\s+['"](.*?)['"]/).flatten
    end
    .push('schema_migrations')
    .flatten.delete_if(&:empty?)
  end

  desc 'list app relate table names'
  task tables: :environment do
    puts app_table_list
  end

  desc 'list database tables names'
  task data_sources: :environment do
    connection = ActiveRecord::Base.connection
    puts connection.data_sources
  end

  task export: :environment do
    export_without_data = %w(sys_devices sys_bang_booms sys_action_logs sys_user_gravatars sys_user_devices)
    config = ActiveRecord::Base.connection_config()
    
    export_filename = %(tmp/export_#{Time.now.to_i}.sh)
    sql_filename = %(tmp/export_#{Time.now.to_i}.sql)
    File.open(export_filename, 'w+') do |file|
      app_table_list.each do |table_name|
        file.puts %(mysqldump -u#{config[:username]} -p#{config[:password]} -h#{config[:host]} #{config[:database]} --add-drop-table #{'-d' if export_without_data.include?(table_name)} #{table_name} >> #{sql_filename};)
      end
      file.puts(%(echo '#{sql_filename}'))
    end

    puts export_filename
  end
end