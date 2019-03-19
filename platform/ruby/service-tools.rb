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
require File.expand_path('../../../agent/lib/utils/http', __FILE__)
require File.expand_path('../../../agent/lib/utils/device', __FILE__)

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
  opts.on('-m', "--monitor all", '监控列表中的服务，未运行则启动') do |value|
    options[:monitor] = value
  end
  opts.on('-p', "--post_to_server", '提交监控服务配置档至服务器') do |value|
    options[:post_to_server] = value
  end
  opts.on('-g', "--guard", '守护监控服务配置，功能同 post_to_server') do |value|
    options[:guard] = value
  end
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

class Service
  class << self
    def options(options)
      @options = options

      @service_config_path = "/etc/sypctl/services.json"
      @service_output_path = "/etc/sypctl/services.output"
      unless File.exists?(@service_config_path)
        puts "警告：本机暂未同步监控服务元信息\n退出操作"
        exit 1
      end

      @data_hash = JSON.parse(File.read(@service_config_path))
      @services  = @data_hash['services']
      @hosts     = @data_hash['hosts'] || {}
      @config    = @data_hash['config'] || {}
      @extra     = @data_hash['extra'] || {}

      ENV["SYPCTL_API"] = ENV["SYPCTL_API_CUSTOM"] || "http://sypctl.com"
    end

    def render
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
        puts "Warning: 未匹配到服务 #{target_service}! \n\n本机配置的服务列表:"
        puts @data_hash['services'].map { |hsh| "- #{hsh['id']}\n" }.join
        exit
      end

      depends = services.map { |service| service['depend'] || [] }.flatten
      services.each do |service|
        service['execute_weight'] = depends.count { |id| service['id'] == id }
      end
      services = services.sort { |a, b| [b['execute_weight'], b['name']] <=> [a['execute_weight'], a['name']] }

      if print_or_not
        if %w(id allid).include?(@options[:list])
          table_rows = (@options[:list] == 'allid' ? @services : services).map do |service|
            [service['name'] || service['id'], service['id'], service['user'], service['execute_weight'], (localhost_services.empty? || localhost_services.include?(service['id']) ? 'yes' : 'no')]
          end
          puts Terminal::Table.new(headings: %w(服务 标识 用户 权重 本机管理), rows: table_rows)
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
        puts "\n# 启动 #{service['name']}\n\n"
        pid_path = render_command(service['pid_path'], service)
        state, message = process_status_by_pid(pid_path)
        if state
          puts message
        else
          start_service(service)
        end
      end

      sleep 3

      status(@options[:start] || target_service || 'all')
    end

    def status(target_service = nil)
      table_rows = list(false, @options[:status] || target_service || 'all').map do |service|
        pid_path = render_command(service['pid_path'], service)
        [service['name'] || service['id'], service['id'], service['user'], service['execute_weight'], process_status_by_pid(pid_path).last]
      end

      table_heads = %w(服务 标识 用户 权重 进程状态)
      puts Terminal::Table.new(headings: table_heads, rows: table_rows)

      data = { heads: table_heads, data: table_rows, timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S") } 
      File.open("/etc/sypctl/services.output", "w:utf-8") { |file| file.puts(data.to_json) }
    end

    def stop(target_service = nil)
      list(false, @options[:stop] || target_service || 'all').reverse.each do |service|
        puts "\n## 关闭 #{service['name']}\n\n"
        service['stop'].each do |command|
          command = render_command(command, service)

          if (service['user'] || whoami) != whoami && need_su_to_execute_command?(command, service)
            command = "su #{service['user']} --login --shell /bin/bash --command \"#{command}\""
          end
          run_command(command)
        end

        pid_path = render_command(service['pid_path'], service)
        kill_process_by_pid(pid_path)
      end
    end

    def restart
      stop(@options[:restart])
      puts "-" * 30
      sleep 3
      start(@options[:restart])
    end

    def monitor
      list(false, 'all').each do |service|
        pid_path = render_command(service['pid_path'], service)
        state, message = process_status_by_pid(pid_path)
        next if state

        puts "\n# 启动 #{service['name']}"
        start_service(service)

        Sypctl::Http.post_behavior({
          behavior: "检测到「#{service['name']}」(#{service['id']}) 服务未运行，执行启动操作(#{whoami})", 
          object_type: 'service', 
          object_id: "#{service['name']}(#{service['id']})"
        }, {}, {print_log: false})
      end

      status('all')
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

    # #service# 
    # 提交监控服务配置档至服务器
    def post_to_server
      output_content, total_count, stopped_count = "FileNotExist", -1, -1
      if File.exists?(@service_output_path)
        output_content = File.read(@service_output_path)
        output_array = JSON.parse(output_content)["data"]
        total_count = output_array.count
        stopped_count = output_array.select { |arr| arr.last.include?("未运行") }.count
      end

      options = {
        uuid: Sypctl::Device.uuid,
        service: {
          uuid: Sypctl::Device.uuid,
          hostname: `hostname`.strip,
          config: File.exists?(@service_config_path) ? File.read(@service_config_path) : "FileNotExist",
          monitor: output_content,
          total_count: total_count,
          stopped_count: stopped_count
        }
      }

      url = "#{ENV['SYPCTL_API']}/api/v1/service"
      Sypctl::Http.post(url, options, {}, {print_log: false})
    end

    def guard
      monitor
      post_to_server
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
      variables = command_origin.scan(/\{\{(.*?)\}\}/).flatten.map(&:strip)
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

    def process_status_by_pid(pid_path)
      if File.exists?(pid_path) && !(pid = File.read(pid_path).strip).empty?
        (pid == `ps ax | awk '{print $1}' | grep -e "^#{pid}$"`.strip ? [true, "运行中(#{pid})"] : [false, "未运行"])
      else
        `rm -f #{pid_path}`
        [false, "未运行，PID 不存在"]
      end
    end

    def kill_process_by_pid(pid_path, try_time = 1)
      if try_time > 3
        puts "中止尝试 Kill 进程 #{pid_path}"
        return false 
      end

      state, message = process_status_by_pid(pid_path)
      return false unless state
      return false unless File.exists?(pid_path)
      
      pid = File.read(pid_path).strip
      if try_time > 1
        puts "查看进程(#{pid})详情:"
        puts `ps aux | grep #{pid}`
      end
      
      puts "#{message}, 第#{try_time}次尝试 KILL 进程, #{pid_path}"
      run_command("kill -KILL #{pid} > /dev/null 2>&1")
      kill_process_by_pid(pid_path, try_time + 1)
    end

    def start_service(service)
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
end

Service.options(options)
Service.send(options.keys.first)