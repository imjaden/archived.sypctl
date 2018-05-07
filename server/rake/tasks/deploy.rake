namespace :deploy do

  def execute_sql(file_path)
    IO.read(file_path).split(';').each do |sql_string|
      puts "mysql> #{sql_string.strip};"
      ActiveRecord::Base.connection.execute(sql_string)
    end
  end

  def execute_bash(file_path)
    puts "bash #{file_path}"
    `bash #{file_path}`
  end

  desc 'deploy:init'
  task :init  do
    script_path = app_root_join('lib/scripts/deploy/171118130427_init_env.sh')
    execute_bash(script_path)
  end

  desc 'deploy:auto'
  task auto: :environment do
    deploy_path = app_tmp_join('deploy')
    script_path = app_root_join('lib/scripts/deploy/*.{sql,sh}')

    `/bin/mkdir -p #{deploy_path}`
    versions_path  = app_tmp_join("deploy/versions-#{ENV['RACK_ENV']}.list")
    versioned_list = File.exist?(versions_path) ? IO.readlines(versions_path).map(&:strip).uniq : []
    Dir.glob(script_path).each do |file_path|
      file_name = File.basename(file_path)
      next if versioned_list.include?(file_name)

      puts "execute: #{file_path}"
      ext_name  = File.extname(file_path)
      case ext_name
      when '.sql' then execute_sql(file_path)
      when '.sh'  then execute_bash(file_path)
      end 

      `echo #{file_name} >> #{versions_path}`
    end
  end

  namespace :db do
    task utf8: :environment do
      conn          = ActiveRecord::Base.connection
      database_name = ActiveRecord::Base.connection_config[:database]
      sql_string    = "alter database #{database_name} default character set utf8;"
      conn.execute(sql_string)
      puts "mysql> #{sql_string}"

      conn.tables.each do |table_name|
        sql_string = "alter table #{table_name} convert to character set utf8;"
        conn.execute(sql_string)
        puts "mysql> #{sql_string}"
      end
    end
  end
end
