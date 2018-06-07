# encoding: utf-8
require 'json'
require 'timeout'
require 'fileutils'

if ARGV.length.zero? || !File.exists?(ARGV[0])
  puts "请传参配置档路径"
  exit
end

config_path = ARGV[0]
config_data = JSON.parse(File.read(config_path))

`echo #{Process.pid} > etl/tmp/msserver.pid`
databases = config_data['databases'].uniq
tables = config_data['tables'].uniq
puts "#{Time.now} - #{databases.length} 个数据库，#{tables.length} 个数据表"

def logger(start_time, database, table, script, result = 'successfully')
  path = "etl/db/log.json" # -#{Time.now.strftime('%y%m%d')}
  File.open(path, "w:utf-8") { |file| file.puts([].to_json) } unless File.exists?(path)
  
  data = JSON.parse(File.read(path))
  data.push({database: database, table: table, start_time: start_time, finish_time: Time.now, executed_time: (Time.now.to_i - start_time.to_i), script: script, result: result})
  File.open(path, "w:utf-8") { |file| file.puts(data.to_json) }

  path = "etl/db/status.json" # -#{Time.now.strftime('%y%m%d')}
  File.open(path, "w:utf-8") { |file| file.puts({}.to_json) } unless File.exists?(path)
  
  data = JSON.parse(File.read(path))
  data["#{database}.#{table}"] = Time.now.strftime('%y%m%d %H:%M:%S')
  data["#{database}.#{table}:result"] = result
  File.open(path, "w:utf-8") { |file| file.puts(data.to_json) }
end

def import_status(database, table)
  path = "etl/db/status.json" # -#{Time.now.strftime('%y%m%d')}
  File.open(path, "w:utf-8") { |file| file.puts({}.to_json) } unless File.exists?(path)
  
  data = JSON.parse(File.read(path))
  data["#{database}.#{table}"]
end

def execute_bash_script(script, database, table)
  start_time = Time.now
  script_path = "etl/tmp/running.sh"
  File.open(script_path, "w+:utf-8") do |file|
    file.puts(script)
  end
  begin
    Timeout::timeout(1.5*60*60) do
      `echo etl/logs/#{database}-#{table}.log > etl/tmp/running.log`
      `bash #{script_path} > etl/logs/#{database}-#{table}.log 2>&1`
    end
  rescue => e

  end
  logger(start_time, database, table, script)
end

def import_total_table_script(database_hash, table_name)
  script = <<-EOF
# --------------------------------------
# database: #{database_hash['database']}
# table: #{table_name}
# start_time: #{Time.now.strftime('%y-%m-%d %H:%M:%S')}
# --------------------------------------
hive -e "drop table if exists #{database_hash['database']}.#{table_name}"

temp_target_dir=/user/hadoop/sqoop_import_#{database_hash['database']}_#{table_name}
hadoop fs -test -e ${temp_target_dir}
[[ $? -eq 0 ]] && hadoop fs -rm -r ${temp_target_dir}

sqoop import "-Dorg.apache.sqoop.splitter.allow_text_splitter=true" \\
    --driver com.microsoft.jdbc.sqlserver.SQLServerDriver \\
    --connect "#{database_hash['connect']}" \\
    --username "${database_hash['username']}" \\
    --password "${database_hash['password']}" \\
    --table=#{table_name} \\
    --target-dir ${temp_target_dir} \\
    --fields-terminated-by "," \\
    --hive-import \\
    --create-hive-table \\
    --hive-table #{database_hash['database']}.#{table_name}
  EOF
end

def import_total_database(databases, tables)
  databases.each do |database_hash|
    script = <<-EOF
# --------------------------------------
# database: #{database_hash['database']}
# start_time: #{Time.now.strftime('%y-%m-%d %H:%M:%S')}
# --------------------------------------
hive -e "create database if not exists #{database_hash['database']}"
    EOF
    execute_bash_script(script, database_hash['database'], '-')

    tables.each do |table_name|
      next if import_status(database_hash['database'], table_name)

      script = import_total_table_script(database_hash, table_name)
      execute_bash_script(script, database_hash['database'], table_name)
    end
  end
end

import_total_database(databases, tables)

`rm -f etl/tmp/msserver.pid`
