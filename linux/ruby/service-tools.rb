# encoding: utf-8
########################################
#  
#  Service Manager
#
########################################
#
# 具体用法:
# $ ruby service-tools.rb --help
# 
require 'json'
require 'timeout'
require 'optparse'
require 'fileutils'
require 'terminal-table'

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: service-tools.rb [args]"
  opts.on('-h', '--help', '参数说明') do
    puts "服务进程管理脚本"
    puts opts
    exit
  end
  opts.on('-l', "--list", '查看管理的服务列表') do |value|
    options[:list] = true
  end
  opts.on('-t', "--check", '检查配置是否正确') do |value|
    options[:check] = true
  end
  opts.on('-s', "--start", '启动服务列表中的应用') do |value|
    options[:start] = true
  end
  opts.on('-e', "--status", '检查服务列表应用的运行状态') do |value|
    options[:status] = true
  end
  opts.on('-k', "--stop", '关闭服务列表中的应用') do |value|
    options[:stop] = true
  end
  opts.on('-r', "--restart", '重启服务列表中的应用') do |value|
    options[:restart] = true
  end
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

def whoami
  `whoami`.strip
end

def process_pid_status(pid_path)
  if File.exists?(pid_path)
    pid = File.read(pid_path).strip
    (pid == `ps ax | awk '{print $1}' | grep -e "^#{pid}$"`.strip ? [true, "运行中(#{pid})"] : [false, "未运行"])
  else
    [false, "未运行，PID 文档不存在"]
  end
end

def list_services(print_or_not = true)
  service_path = "/etc/sypctl/services.json"
  unless File.exists?(service_path)
    puts "Error: 配置档不存在，请创建并配置 /etc/sypctl/services.json\n退出操作"
    exit 1
  end

  services = JSON.parse(File.read(service_path))
  services.each { |service|  puts JSON.pretty_generate(service) } if print_or_not
  services
rescue => e
  puts e.message
end

# 必填项: name, start_commands, stop_commands, pid_path
# user 默认为当前运行账号
def check_services
  errors = list_services(false).map do |service|
    (%w(name start_commands stop_commands pid_path) - service.keys).map do |key|
      "#{service['name']} cannot detect key `#{key}`"
    end
  end.flatten

  if errors.empty?
    puts "nginx: the configuration file /etc/sypctl/services.json syntax is ok"
    # nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
    # nginx: configuration file /etc/nginx/nginx.conf test is successful
  else
    puts errors
  end
end

def start_services
  list_services(false).each do |service|
    puts "\n## 启动 #{service['name']}\n\n"
    running_state, running_text = process_pid_status(service['pid_path'])
    if running_state
      puts running_text
    else
      service['start_commands'].each do |command|
        command = "sudo -p - #{service['user']} bash -c \"command\"" if (service['user'] || whoami) != whoami
        puts "$ #{command}"
        puts `#{command}`
      end
    end
  end

  sleep 1
  status_services
end

def status_services
  table_rows = list_services(false).map do |service|
    [service['group'] || service['name'], service['name'], process_pid_status(service['pid_path']).last]
  end

  puts Terminal::Table.new(headings: %w(群组 服务 进程状态), rows: table_rows)
end

def stop_services
  list_services(false).each do |service|
    puts "\n## 关闭 #{service['name']}\n\n"
    running_state, running_text = process_pid_status(service['pid_path'])
    if running_state
      service['stop_commands'].each do |command|
        command.scan(/\{\{(.*?)\}\}/).flatten.each do |variable|
          command.gsub!("{{#{variable}}}", service['pid_path']) if variable.strip == 'pid_path'
        end
        command = "sudo -p - #{service['user']} bash -c \"command\"" if service['user'] != whoami
        puts "$ #{command}"
        puts `#{command}`
      end
    else
      puts running_text
    end
  end
end

def restart_services
  stop_services
  puts "-" * 30
  start_services
end

send("#{options.keys.first}_services")