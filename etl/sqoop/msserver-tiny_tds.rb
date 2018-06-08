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

config_data["databases"].each do |database|
  ruby_script = <<-EOF
# encoding: utf-8
require 'tiny_tds'

begin
  @client = TinyTds::Client.new(username: "#{database['username']}", password: "#{database['password']}", host: "#{database['host']}", port: "#{database['port']}")
  @client.execute('select @@version').each do |row| 
    puts row
  end
  @client.close
rescue => e
  puts e.message
end
  EOF

  File.open("#{database['host']}.rb", "w:utf-8") do |file|
    file.puts(ruby_script)
  end
end

