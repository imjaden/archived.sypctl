# encoding: utf-8
require 'json'
require 'timeout'
require 'fileutils'

if ARGV.length.zero? || !File.exists?(ARGV[0])
  puts "请传参配置档路径"
  exit
end

if ARGV.length == 1 || !File.exists?(ARGV[1])
  puts "请传参 SQL 文档路径"
  exit
end

config_path = ARGV[0]
config_data = JSON.parse(File.read(config_path))
sql_path = ARGV[1]
sql_content = File.read(sql_path)

config_data["databases"].each do |database|
  script_path = "#{Dir.pwd}/tmp/#{database['database']}-#{database['host']}-#{database['port']}.rb"
  sql_string = "use #{database['database']};\n#{sql_content}"
  ruby_script = <<-EOF
# encoding: utf-8
# 数据源：#{database['host']}:#{database['port']}@#{database['database']}
# 脚本：#{script_path}
require 'json'
require 'tiny_tds'
require 'terminal-table'

begin
  @client = TinyTds::Client.new(username: "#{database['username']}", password: "#{database['password']}", host: "#{database['host']}", port: #{database['port']}, timeout: 10000)
  result = @client.execute("#{sql_string}").to_a

  if result.length > 0
    headers = result[0].keys
    datas = result.map do |hsh|
      headers.map { |key| hsh[key] }
    end
    table = Terminal::Table.new(headings: headers, rows: datas)
    puts table
  else
    puts "查询无结果"
  end

  @client.close
rescue => e
  puts e.message
end
  EOF

  File.open(script_path, "w:utf-8") do |file|
    file.puts(ruby_script)
  end

  puts "*" * 20
  puts "数据源：#{database['host']}:#{database['port']}@#{database['database']}"
  puts "脚本：#{script_path}"
  puts "SQL:"
  puts sql_string
  puts "*" * 20
  start_time = Time.now
  puts `ruby #{script_path}`
  puts "执行时间：#{(Time.now - start_time)}s"
  puts
end
