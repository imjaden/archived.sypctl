# encoding: utf-8
########################################
#  
#  SyncMySQL Manager v1.0
#
########################################
#
# 业务需求：从数据库from(MySQL) 迁移所有数据库(系统库除外)至数据库to(MySQL)
# 
# 代码逻辑:
# 1. 测试数据库 from/to 连接成功，否则退出操作
# 2. 初始化待做事项配置档
#     2.1 查询数据库 from 中所有数据库列表
#     2.2 在数据库 to 创建 from 中所有数据库
# 3. 启动两个进程 threadFrom/threadTo
#     3.1 进程 threadFrom 执行导出操作
#         3.1.1 获取待导出的数据库列表
#         3.1.2 执行导出数据库操作
#         3.1.3 把导出的数据库名称添加到已导出列表
#         3.1.3 全部导出后则停止操作，等待进程 threadTo 导入完成
#     3.2 进程 threadTo 执行导入操作
#         3.2.1 查看已导出列表，为空则等待
#         3.2.2 已导出列表不为空，则执行导入数据库操作
#         3.2.3 导入完成后，则把数据库名称添加到已导入列表
#         3.2.4 确认待导入列表是否是全部导入，是，则退出脚本操作
# 3. 进程 threadFrom/threadTo 结伴而行，以 threadFrom 始以 threadTo 终
#
# 迁移配置档:
# {
#   "from": {
#     "host": "remote-host",
#     "port": "3306",
#     "username": "username",
#     "password": "password",
#     "database": "database"
#   },
#   "to": {
#     "host": "127.0.0.1",
#     "port": "3306",
#     "username": "root",
#     "password": "password",
#     "database": "database"
#   }
# }
#
# 注意事项: 
# - MySQL 数据库不同版本中 mysqldump 操作要求必须包含或不能包含 --set-gtid-purged=OFF
# - 具体是否需求传参根据 mysql 导出报表日志来判断
#
# 导出报告文件:
# - 导出sql：temp/{database}.sql
# - 导出sql 报错：temp/{database}.export-err
# - 导入sql 报表: temp/{database}.import-err
#
# 运行脚本: 
# $ mkdir -p tmp/sync-mysql
# $ vim sync-mysql.json
# $ ruby sync-mysql-tools.rb --config=sync-mysql.json --temp=tmp/sync-mysql
#
# 运行 sypctl
# $ sypctl sync:mysql --config=$(readlink -f config.json) --temp=$(readlink -f tmp/sync-mysql/)
#
require 'json'
require 'mysql2'
require 'optparse'
require 'fileutils'
require 'terminal-table'

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: service-tools.rb [args]"
  opts.on('-h', '--help', '参数说明') do
    puts "迁移 MySQL 数据库工具"
    puts opts
    exit 1
  end
  opts.on('-c', "--config path", '迁移配置档') do |value|
    options[:config] = value
  end
  opts.on('-t', "--temp path", '临时报表目录') do |value|
    options[:temp] = value
  end
  options[:'set-gtid-purged'] = false
  opts.on('-s', "--set-gtid-purged", '导出时是否带参数--set-gtid-purged=OFF, 默认不带') do |value|
    options[:'set-gtid-purged'] = true
  end
  options[:'ignore-log-tables'] = true
  opts.on('-i', "--ignore-log-tables", '导出时是否忽略 log[s]作后缀的业务表, 默认忽略') do |value|
    options[:'ignore-log-tables'] = false
  end
end.parse!
options[:temp] ||= Dir.pwd

puts `ruby #{__FILE__} -h` if options.keys.empty?

def timestamp; Time.now.strftime('%y/%m/%d %H:%M:%S'); end
ignore_databases = ['sys', 'mysql', 'information_schema', 'performance_schema']
config = JSON.parse(File.read(options[:config]))
ignore_table_regexp = "(_|-)logs?$"
is_config_file_open = false

['from', 'to'].each do |type|
  begin
    client = Mysql2::Client.new(config[type])
    client.query("select version()")
    client.close
  rescue => e
    puts "数据库 #{type} 连接失败:#{e.message}, 退出操作"
    exit 1
  end
end

client = Mysql2::Client.new(config['from'])
databases = client.query("show databases").map { |h| h.values }.flatten
client.close
report = (databases - ignore_databases).each_with_object({}) do |database, h|
  h[database] = {
    database: database,
    database_size: 0,
    exported: 'todo',
    exported_duration: 'todo',
    imported: 'todo',
    imported_duration: 'todo'
  }
end

client = Mysql2::Client.new(config['to'])
(databases - ignore_databases).each do |database|
  client.query("create database if not exists #{database};")
end
client.close

report_path = File.join(options[:temp], 'sync-report.json')
File.open(report_path, 'w:utf-8') { |file| file.puts(report.to_json) } unless File.exists?(report_path)

threadFrom = Thread.new do
  while true
    todo_list = JSON.parse(File.read(report_path)).values.select { |h| h['exported'] == 'todo' }
    todo_list.each_with_index do |item, index|

      ignore_tables_sql = ''
      if options[:'ignore-log-tables']
        config['from']['database'] = item['database']
        client = Mysql2::Client.new(config['from'])
        tables = client.query("show tables").map { |h| h.values }.flatten
        client.close
        ignore_tables = tables.select { |table| table =~ Regexp::new(ignore_table_regexp) }
        ignore_tables_sql = ignore_tables.map { |table| "--ignore-table=#{item['database']}.#{table}" }.join(" ")
      end

      option_set_gtid_purged = options[:'set-gtid-purged'] ? '--set-gtid-purged=OFF' : ''
      bash_script = "mysqldump #{option_set_gtid_purged} -h#{config['from']['host']} -u#{config['from']['username']} -p#{config['from']['password']} -P#{config['from']['port']} --default-character-set=utf8 #{item['database']} #{ignore_tables_sql} 1> #{options[:temp]}/#{item['database']}.sql 2> #{options[:temp]}/#{item['database']}.export-err"
      begin_time = Time.now

      puts "#{timestamp} - threadFrom, #{item['database']}(#{index+1}/#{todo_list.length}), 准备导出"
      puts "#{timestamp} - threadFrom, #{bash_script}"
      system(bash_script)
      puts "#{timestamp} - threadFrom, #{item['database']}(#{index+1}/#{todo_list.length}), 准备完成, 用时 #{(Time.now - begin_time).round(2)}s"

      sleep(rand) if is_config_file_open
      is_config_file_open = true
      report = JSON.parse(File.read(report_path))
      report[item['database']]['exported'] = 'done'
      report[item['database']]['exported_at'] = timestamp
      report[item['database']]['exported_duration'] = (Time.now - begin_time).round(2)
      File.open(report_path, 'w:utf-8') { |file| file.puts(report.to_json) }
      is_config_file_open = false
    end
    if todo_list.empty?
      puts "#{timestamp} - threadFrom, 导出完成，休息 2s 等待 threadTo"
      sleep 2
    end
  end
end

threadTo = Thread.new do
  while true
    report = JSON.parse(File.read(report_path)).values
    if report.all? { |h| h['exported'] == 'todo' } || (!report.all? { |h| h['exported'] == 'done' } && !report.any? { |h| h['exported'] == 'done' && h['imported'] == 'todo' })
      puts "#{timestamp} - threadTo, 无待导入事项，休息 2s 等待 threadFrom"
      sleep 5
    elsif report.all? { |h| h['exported'] == 'done' && h['imported'] == 'done' }
      puts "#{timestamp} - threadTo, 全部导出，退出操作"
      exit 1
    else
      todo_list = report.select { |h| h['exported'] == 'done' && h['imported'] == 'todo' }

      todo_list.each_with_index do |item, index|
        bash_script = "mysql -h#{config['to']['host']} -u#{config['to']['username']} -p#{config['to']['password']} -P#{config['to']['port']} --default-character-set=utf8 #{item['database']} < #{options[:temp]}/#{item['database']}.sql 2> #{options[:temp]}/#{item['database']}.import-err"
        begin_time = Time.now

        puts "#{timestamp} - threadTo, #{item['database']}(#{index+1}/#{todo_list.length}), 准备导入"
        puts "#{timestamp} - threadTo, #{bash_script}"
        system(bash_script)
        puts "#{timestamp} - threadTo, #{item['database']}(#{index+1}/#{todo_list.length}), 导入完成, 用时 #{(Time.now - begin_time).round(2)}s"

        sleep(rand) if is_config_file_open
        is_config_file_open = true
        report = JSON.parse(File.read(report_path))
        report[item['database']]['imported'] = 'done'
        report[item['database']]['imported_at'] = timestamp
        report[item['database']]['imported_duration'] = (Time.now - begin_time).round(2)
        File.open(report_path, 'w:utf-8') { |file| file.puts(report.to_json) }
        is_config_file_open = true
      end
    end
  end
end

[threadFrom, threadTo].map(&:join)

