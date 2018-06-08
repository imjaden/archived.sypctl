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
@import_mode = ARGV[1] || 'normal'
@import_mode_human = (@import_mode == 'normal' ? '普通模式' : '清理超时模式')
puts "#{Time.now} - 导数模式: #{@import_mode_human}"

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
  if @import_mode == 'expired'
    return !data["#{database}.#{table}:result"].to_s.include?("expired")
  end

  return data["#{database}.#{table}:result"]
end

def execute_bash_script(database_hash, table_hash)
  start_time = Time.now

  database_name = database_hash['database']
  table_name = table_hash['table_name'] || '-'
  timeout = table_hash['timeout'] || 0.5

  if table_name == '-'
    script = import_create_database_or_not(database_hash, table_name, timeout)
  else
    script = import_total_table_script(database_hash, table_hash, timeout)
  end

  script_path = "etl/tmp/running.sh"
  File.open(script_path, "w+:utf-8") { |file| file.puts(script) }

  result = 'successfully'
  begin
    Timeout::timeout(timeout*60*60) do
      File.open("etl/logs/#{database_name}-#{table_name}.log", "w:utf-8") { |file| file.puts(script) }
      `echo etl/logs/#{database_name}-#{table_name}.log > etl/tmp/running.log`
      `echo "" >> etl/logs/#{database_name}-#{table_name}.log 2>&1`
      `echo "# output below:" >> etl/logs/#{database_name}-#{table_name}.log 2>&1`
      `echo "" >> etl/logs/#{database_name}-#{table_name}.log 2>&1`
      `bash #{script_path} >> etl/logs/#{database_name}-#{table_name}.log 2>&1`
    end
  rescue => e
    result = "#{e.message}(timeout limit: #{timeout}h)"
  end
  logger(start_time, database_name, table_name, script, result)
end

def import_create_database_or_not(database_hash, table_name, timeout)
  script = <<-EOF
# --------------------------------------
# database: #{database_hash['database']}
# start_time: #{Time.now.strftime('%y-%m-%d %H:%M:%S')}
# timeout_limit: #{timeout}
# --------------------------------------
hive -e "create database if not exists #{database_hash['database']}"
  EOF
end

def import_total_table_script(database_hash, table_hash, timeout)
  database_name = database_hash['database']
  table_name = table_hash['table_name']

  script = <<-EOF
# --------------------------------------
# database_name: #{database_name}
# table_name: #{table_name}
# start_time: #{Time.now.strftime('%y-%m-%d %H:%M:%S')}
# timeout_limit: #{timeout}h
# row_count: #{table_hash['row_count']} (仅供参考)
# import_mode: #{@import_mode_human}
# --------------------------------------
hive -e "drop table if exists #{database_name}.#{table_name}"

temp_target_dir=/user/hadoop/sqoop_import_#{database_name}_#{table_name}
hadoop fs -test -e ${temp_target_dir}
[[ $? -eq 0 ]] && hadoop fs -rm -r ${temp_target_dir}

sqoop import "-Dorg.apache.sqoop.splitter.allow_text_splitter=true" \\
    --driver com.microsoft.jdbc.sqlserver.SQLServerDriver \\
    --connect "#{database_hash['connect']}" \\
    --username "#{database_hash['username']}" \\
    --password "#{database_hash['password']}" \\
    --table=#{table_name} \\
    --target-dir ${temp_target_dir} \\
    --fields-terminated-by "," \\
    --hive-import \\
    --create-hive-table \\
    --hive-table #{database_name}.#{table_name}
  EOF
end

def import_total_database(databases, tables)
  databases.each do |database_hash|
    execute_bash_script(database_hash, {}) unless import_status(database_hash['database'], "-")

    tables.each do |table_hash|
      next if import_status(database_hash['database'], table_hash['table_name'])

      execute_bash_script(database_hash, table_hash)
    end
  end
end

import_total_database(databases, tables)

`rm -f etl/tmp/msserver.pid`
