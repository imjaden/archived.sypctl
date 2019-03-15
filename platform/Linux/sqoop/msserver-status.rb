# encoding: utf-8
require 'json'
require 'timeout'
require 'fileutils'

path = "etl/db/status.json" # -#{Time.now.strftime('%y%m%d')}
File.open(path, "w:utf-8") { |file| file.puts({}.to_json) } unless File.exists?(path)
data = JSON.parse(File.read(path))
puts "各数据库.数据表导数状态: "
puts JSON.pretty_generate(data)

puts "=" * 20
path = "etl/db/log.json" # -#{Time.now.strftime('%y%m%d')}
File.open(path, "w:utf-8") { |file| file.puts([].to_json) } unless File.exists?(path)
data = JSON.parse(File.read(path))
puts "共产生 #{data.length} 条日志: #{Dir.pwd}/#{path}"

puts "=" * 20
script_path = "etl/tmp/running.sh"
if File.exists?(script_path)
  puts "最近运行的脚本:"
  puts
  puts File.read(script_path)
else
  puts "最近未运行脚本！"
end

puts "=" * 20
logger_path = "etl/tmp/running.log"
if File.exists?(logger_path)
  running_log = File.read(logger_path).strip
  puts "正在运行脚本的日志:"
  puts "$ tail -f #{Dir.pwd}/#{running_log}"
else
  puts "未监测到运行脚本的日志！"
end

puts "=" * 20
pidpath = 'etl/tmp/msserver.pid'

if File.exists?(pidpath)
  pid = File.read(pidpath).strip
  `ps -ax | awk '{print $1}' | grep -e "^#{pid}$" > /dev/null 2>&1 || rm -f etl/tmp/msserver.pid`
end

if File.exists?(pidpath)
  pid = File.read(pidpath).strip
  puts "sqoop 导数进程正在运行(#{pid}):"
  puts `ps aux | grep #{pid} | grep -v grep`
  exit 0
else
  puts "未监测到 sqoop 导数进程！"
  exit 1
end