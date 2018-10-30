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
  opts.on('-l', "--list id", '查看管理的服务列表') do |value|
    options[:list] = value
  end
  opts.on('-t', "--check", '检查配置是否正确') do |value|
    options[:check] = true
  end
  opts.on('-s', "--start service", '启动服务列表中的应用') do |value|
    options[:start] = value
  end
  opts.on('-e', "--status service", '检查服务列表应用的运行状态') do |value|
    options[:status] = value
  end
  opts.on('-k', "--stop service", '关闭服务列表中的应用') do |value|
    options[:stop] = value
  end
  opts.on('-r', "--restart service", '重启服务列表中的应用') do |value|
    options[:restart] = value
  end
  opts.on('-r', "--render", '渲染命令中嵌套的变量') do |value|
    options[:render] = true
  end
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

class Service
  class << self
    def options(options)
      @options = options
    end

    def render()
      service_path = "/etc/sypctl/services.json"
      unless File.exists?(service_path)
        puts "Error: 配置档不存在，请创建并配置 /etc/sypctl/services.json\n退出操作"
        exit 1
      end

      data_hash = JSON.parse(File.read(service_path))
      data_hash['services'].map do |service|
        service['start'] = service['start'].map { |command| render_command(command, service) }
        service['stop'] = service['stop'].map { |command| render_command(command, service) }
        service['pidpath'] = render_command(service['pidpath'], service)
        service
      end
      puts JSON.pretty_generate(data_hash)
    rescue => e
      puts e.message
    end

    def list(print_or_not = true, target_service = 'all')
      service_path = "/etc/sypctl/services.json"
      unless File.exists?(service_path)
        puts "Error: 配置档不存在，请创建并配置 /etc/sypctl/services.json\n退出操作"
        exit 1
      end

      data_hash = JSON.parse(File.read(service_path))
      services = data_hash['services']
      localhost_services = data_hash[hostname] || []
      if print_or_not
        if @options[:list] == 'id'
          table_rows = services.map do |service|
            [service['name'] || service['id'], service['id'], service['user'], (localhost_services.empty? || localhost_services.include?(service['id']) ? 'yes' : 'no')]
          end
          puts Terminal::Table.new(headings: %w(服务 标识 用户 本机管理), rows: table_rows)
        else
          puts JSON.pretty_generate(data_hash)
        end
      end

      services = services.select { |hsh| localhost_services.include?(hsh['id']) } unless localhost_services.empty?
      services = services.select { |hsh| hsh['id'] == target_service } if target_service != 'all'

      if services.empty?
        puts "Warning: 未匹配到服务 #{target_service}! \n本机配置的服务列表:"
        puts data_hash['services'].map { |hsh| hsh['id'] }.join("\n")
        exit
      end

      services
    rescue => e
      puts e.message
    end

    def start(target_service = nil)
      list(false, @options[:start] || target_service || 'all').each do |service|
        puts "\n# 启动 #{service['name']}"
        pidpath = render_command(service['pidpath'], service)
        running_state, running_text = process_pid_status(pidpath)
        if running_state
          puts running_text
        else
          service['start'].each do |command|
            command = render_command(command, service)
            command = "su -p - #{service['user']} bash -c \"#{command}\"" if (service['user'] || whoami) != whoami
            run_command(command)
            sleep 1
          end
        end
      end

      sleep 1

      status(@options[:start] || target_service || 'all')
    end

    def status(target_service = nil)
      table_rows = list(false, @options[:status] || target_service || 'all').map do |service|
        pidpath = render_command(service['pidpath'], service)
        [service['name'] || service['id'], service['id'], service['user'], process_pid_status(pidpath).last]
      end

      puts Terminal::Table.new(headings: %w(服务 标识 用户 进程状态), rows: table_rows)
    end

    def stop(target_service = nil)
      list(false, @options[:stop] || target_service || 'all').each do |service|
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

    def restart
      stop(@options[:restart])
      puts "-" * 30
      start(@options[:restart])
    end

    # 预留关键字: name, start, stop, pidpath
    # user 默认为当前运行账号
    def check(target_service = nil)
      errors = list(false, @options[:list] || target_service || 'all').map do |service|
        (%w(name id user start stop pidpath) - service.keys).map do |key|
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

    private

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
      command_origin = command.clone
      variables = command_origin.scan(/\{\{(.*?)\}\}/).flatten
      return command if variables.empty?

      variables.each do |variable|
        if service.keys.include?(variable)
          command.gsub!("{{#{variable}}}", service[variable]) 
        else
          puts "warning: #{command_origin} 包含未知变量 #{variable}"
        end
      end
      render_command(command, service)
    rescue => e
      puts e.message
      puts "command: #{command}"
      puts "service: #{service}"
    end

    def process_pid_status(pidpath)
      if File.exists?(pidpath)
        pid = File.read(pidpath).strip
        (pid == `ps ax | awk '{print $1}' | grep -e "^#{pid}$"`.strip ? [true, "运行中(#{pid})"] : [false, "未运行"])
      else
        [false, "未运行，PID 文档不存在"]
      end
    end
  end
end

Service.options(options)
Service.send(options.keys.first)
