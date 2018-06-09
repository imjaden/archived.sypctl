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
sql_path = ARGV[0]
sql_content = File.read(sql_path)

config_data["databases"].each do |database|
  sql_string = "use #{database['database']}; #{sql_content}"
  ruby_script = <<-EOF
# encoding: utf-8
require 'tiny_tds'

begin
  @client = TinyTds::Client.new(username: "#{database['username']}", password: "#{database['password']}", host: "#{database['host']}", port: "#{database['port']}")
  @client.execute("#{sql_string}").each do |row| 
    puts row
  end
  @client.close
rescue => e
  puts e.message
end
  EOF

  script_path = "tmp/#{database['host']}.rb"
  File.open(script_path, "w:utf-8") do |file|
    file.puts(ruby_script)
  end

  puts "*" * 20
  puts "#{database['host']}:#{database['port']}@#{database['database']}"
  puts sql_string
  puts "*" * 20

  ruby script_path
end

