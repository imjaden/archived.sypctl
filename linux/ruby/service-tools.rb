# encoding: utf-8
########################################
#  
#  Service Manager v1.0
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

def hostname
  `hostname`.strip
end

def run_command(command)
  puts "$ #{command}"
  system(command)
end

def render_command(command, service)
  dup_command = command.clone
  dup_command.scan(/\{\{(.*?)\}\}/).flatten.each do |variable|
    if service.keys.include?(variable)
      command.gsub!("{{#{variable}}}", service[variable]) 
    else
      puts "warning: #{dup_command} 包含未知变量 #{variable}"
    end
  end
  command
end

def process_pid_status(pidpath)
  if File.exists?(pidpath)
    pid = File.read(pidpath).strip
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

  data_hash = JSON.parse(File.read(service_path))
  services = data_hash['services']
  localhost_services = data_hash[hostname] || []
  services = services.select { |hsh| localhost_services.include?(hsh['name']) } unless localhost_services.empty?
  services.each { |service|  puts JSON.pretty_generate(service) } if print_or_not
  services
rescue => e
  puts e.message
end

# 必填项: name, start, stop, pidpath
# user 默认为当前运行账号
def check_services
  errors = list_services(false).map do |service|
    (%w(group name user start stop pidpath) - service.keys).map do |key|
      "#{service['name']} 未配置 key: `#{key}`"
    end
  end.flatten

  if errors.empty?
    puts "sypctl: the configuration file /etc/sypctl/services.json syntax is ok"
    # nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
    # nginx: configuration file /etc/nginx/nginx.conf test is successful
  else
    puts errors
  end
end

def refresh_crontab
end

def start_services
  list_services(false).each do |service|
    puts "\n# 启动 #{service['name']}"
    pidpath = render_command(service['pidpath'], service)
    running_state, running_text = process_pid_status(pidpath)
    if running_state
      puts running_text
    else
      service['start'].each do |command|
        command = render_command(command, service)
        command = "sudo -p - #{service['user']} bash -c \"command\"" if (service['user'] || whoami) != whoami
        run_command(command)
      end
    end
  end

  sleep 1
  status_services

  refresh_crontab
end

def status_services
  table_rows = list_services(false).map do |service|
    pidpath = render_command(service['pidpath'], service)
    [service['group'] || service['name'], service['name'], process_pid_status(pidpath).last]
  end

  puts Terminal::Table.new(headings: %w(群组 服务 进程状态), rows: table_rows)
end

def stop_services
  list_services(false).each do |service|
    puts "\n## 关闭 #{service['name']}"
    pidpath = render_command(service['pidpath'], service)
    running_state, running_text = process_pid_status(pidpath)
    if running_state
      service['stop'].each do |command|
        command = render_command(command, service)
        command = "sudo -p - #{service['user']} bash -c \"command\"" if service['user'] != whoami
        run_command(command)
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