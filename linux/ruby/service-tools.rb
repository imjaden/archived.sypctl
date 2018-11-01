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
  opts.on('-r', "--render service", '渲染命令中嵌套的变量') do |value|
    options[:render] = value
  end
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

class Service
  class << self
    def options(options)
      @options = options

      service_path = "/etc/sypctl/services.json"
      unless File.exists?(service_path)
        puts "Error: 配置档不存在，请创建并配置 /etc/sypctl/services.json\n退出操作"
        exit 1
      end

      @data_hash = JSON.parse(File.read(service_path))
      @services = @data_hash['services']
      @hosts = @data_hash['hosts'] || {}
      @config = @data_hash['config'] || {}
      @extra = @data_hash['extra'] || {}
    end

    def render()
      services = @data_hash['services']
      services = services.select { |hsh| hsh['id'] == @options[:render] } if @options[:render] != 'all'

      services = services.map do |service|
        service['start'] = service['start'].map { |command| render_command(command, service) }
        service['stop'] = service['stop'].map { |command| render_command(command, service) }
        service['pid_path'] = render_command(service['pid_path'], service)
        service
      end
      puts JSON.pretty_generate(services)
    rescue => e
      puts e.message
    end

    def list(print_or_not = true, target_service = 'all')
      localhost_services = @hosts[hostname] || []
      services = @data_hash['services']
      services = services.select { |hsh| localhost_services.include?(hsh['id']) } unless localhost_services.empty?
      services = services.select { |hsh| target_service.split(",").include?(hsh['id'])  } if target_service != 'all'

      if services.empty?
        puts "Warning: 未匹配到服务 #{target_service}! \n本机配置的服务列表:"
        puts data_hash['services'].map { |hsh| hsh['id'] }.join("\n")
        exit
      end

      depends = services.map { |service| service['depend'] || [] }.flatten
      services.each do |service|
        service['execute_weight'] = depends.count { |id| service['id'] == id }
      end
      services = services.sort { |a, b| [b['execute_weight'], b['id']] <=> [a['execute_weight'], a['id']] }

      if print_or_not
        if @options[:list] == 'id'
          table_rows = services.map do |service|
            [service['name'] || service['id'], service['id'], service['user'], service['execute_weight'], (localhost_services.empty? || localhost_services.include?(service['id']) ? 'yes' : 'no')]
          end
          puts Terminal::Table.new(headings: %w(服务 标识 用户 执行权重 本机管理), rows: table_rows)
        else
          puts JSON.pretty_generate(services)
        end
      end

      services
    rescue => e
      puts e.message
    end

    def start(target_service = nil)
      list(false, @options[:start] || target_service || 'all').each do |service|
        puts "\n# 启动 #{service['name']}"
        pid_path = render_command(service['pid_path'], service)
        running_state, running_text = process_pid_status(pid_path)
        if running_state
          puts running_text
        else
          service['start'].each do |command|
            command = render_command(command, service)

            # 使用 su 切换用户执行命令，需要满足以下两点:
            # 1. 运行账号不是当前用户
            # 2. 没有指明不需要切换用户操作命令(开头命令)
            if (service['user'] || whoami) != whoami && need_su_to_execute_command?(command, service)
              command = "su #{service['user']} --login --shell /bin/bash --command \"#{command}\"" 
            end
            run_command(command)
          end
        end
      end

      sleep 1

      status(@options[:start] || target_service || 'all')
    end

    def status(target_service = nil)
      table_rows = list(false, @options[:status] || target_service || 'all').map do |service|
        pid_path = render_command(service['pid_path'], service)
        [service['name'] || service['id'], service['id'], service['user'], service['execute_weight'], process_pid_status(pid_path).last]
      end

      puts Terminal::Table.new(headings: %w(服务 标识 用户 执行权重 进程状态), rows: table_rows)
    end

    def stop(target_service = nil)
      list(false, @options[:stop] || target_service || 'all').reverse.each do |service|
        puts "\n## 关闭 #{service['name']}"
        pid_path = render_command(service['pid_path'], service)
        service['stop'].each do |command|
          command = render_command(command, service)

          if (service['user'] || whoami) != whoami && need_su_to_execute_command?(command, service)
            command = "su #{service['user']} --login --shell /bin/bash --command \"#{command}\""
          end
          run_command(command)
        end
      end
    end

    def restart
      stop(@options[:restart])
      puts "-" * 30
      start(@options[:restart])
    end

    # 预留关键字: name, start, stop, pid_path
    # user 默认为当前运行账号
    def check(target_service = nil)
      errors = list(false, @options[:list] || target_service || 'all').map do |service|
        (%w(name id user start stop pid_path) - service.keys).map do |key|
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

    def need_su_to_execute_command?(command, service)
      keywords = (service['switch_user_except'] || [])
      return !keywords.any? { |keyword| command.start_with?(keyword) } unless keywords.empty?

      keywords = (@config['switch_user_except'] || [])
      return !keywords.any? { |keyword| command.start_with?(keyword) }
    end

    def render_variable(key, hsh, command)
      return hsh[key] if hsh[key]

      puts "warning: #{command} 包含未知key: #{key}"
      return "##{key}#"
    end

    def render_command(command, service)
      command_origin = command.clone
      variables = command_origin.scan(/\{\{(.*?)\}\}/).flatten
      return command if variables.empty?

      # 变量优先级: 私有 extra > 全局 extra > service 关键字
      extra = @extra.merge(service['extra'] || {})
      variables_hash = service.merge(extra)
      variables.each do |variable|
        command.gsub!("{{#{variable}}}", render_variable(variable, variables_hash, command_origin))
      end
      render_command(command, service)
    rescue => e
      puts e.message
      puts "command: #{command}"
      puts "service: #{service}"
    end

    def process_pid_status(pid_path)
      if File.exists?(pid_path)
        pid = File.read(pid_path).strip
        (pid == `ps ax | awk '{print $1}' | grep -e "^#{pid}$"`.strip ? [true, "运行中(#{pid})"] : [false, "未运行"])
      else
        [false, "未运行，PID 文档不存在"]
      end
    end
  end
end

Service.options(options)
Service.send(options.keys.first)
