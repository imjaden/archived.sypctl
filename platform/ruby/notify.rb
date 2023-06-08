# encoding: utf-8
########################################
#  
#  API Guard v1.0
#
########################################
#
# 1. 每分钟请求一次API, 并记录响应状态
# 2. API 响应异常时，则发送短信通知，并记录通知时间
# 3. 短信发送频率为十分钟，即发送异常通知后的十分钟不再发送短信通知，但会记录API状态，
#    作为下次短信通知的内容
#
# 具体用法:
# $ ruby api-guard.rb --help
# 

require 'json'
require 'timeout'
require 'optparse'
require 'fileutils'
require 'digest/md5'
require File.expand_path('../../../agent/lib/utils/device', __FILE__)
require File.expand_path('../../../agent/lib/utils/http', __FILE__)
require File.expand_path('../../../agent/lib/utils/aliyun_sms', __FILE__)
require File.expand_path('../../../agent/lib/utils/qyweixin_webhook', __FILE__)

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: notify.rb [args]"
  opts.on('-h', '--help', '参数说明') do
    puts "服务进程管理脚本"
    puts opts
    exit
  end
  opts.on('-l', "--list", '查看今天通知') do |value|
    options[:list] = value
  end

  (1..7).to_a.each do |offset|
    opts.on("--list-#{offset}", "查看#{offset}天前通知") do |value|
      options["list_#{offset}".to_sym] = value
    end
  end

  opts.on('-r', "--render", '打印配置档') do |value|
    options[:render] = value
  end
  opts.on('-g', "--guard", '执行守护任务') do |value|
    options[:guard] = value
  end

  opts.on('-e', "--enable service", '激活应用') do |value|
    options[:enable] = value
  end
  opts.on('-d', "--disable service", '禁用应用') do |value|
    options[:disable] = value
  end
  opts.on('-i', "--disabled_in interval", '禁用一段时间disabled_in') do |value|
    options[:disabled_in] = value.to_i
    options[:state] = 'disabled_in'
  end
  opts.on('-s', "--state", '应用状态') do |value|
    options[:state] = value
  end
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

config_path = "/etc/sypctl/notify.json"
unless File.exist?(config_path)
  puts "Error: not found #{config_path}"
  exit(1)
end 
options[:config_path] = config_path

class Notify
  class << self
    def options(options)
      @options = options
      @config = JSON.parse(File.read(@options[:config_path]))
      @notify_type = check_notify_type

      @archived_path = File.join(ENV['SYPCTL_HOME'], "agent/db/#{@notify_type}-notify", 'archived')
      @state_path = File.join(@archived_path, "../state.json")

      FileUtils.mkdir_p(@archived_path) unless File.exist?(@archived_path)

      check_state if (['enable', 'disable', 'disabled_in'] & @options.keys.map(&:to_s)).length.zero?
    end

    def check_state
      state_hash = JSON.parse(File.read(@state_path)) rescue {}
      _state = state_hash['state']
      if _state == 'disable'
        puts _state
        exit
      end

      if _state == 'disabled_in' && Time.now.to_i < state_hash['disabled_in'].to_i
        puts "disabled_in #{Time.at(state_hash['disabled_in'])}"
        exit
      end
    end

    def state
      state_hash = JSON.parse(File.read(@state_path)) rescue {}
      _state = state_hash['state'] || 'enable'
      if _state == 'enable'
        puts _state
      else
        check_state
      end
    end

    def enable
      state_hash = JSON.parse(File.read(@state_path)) rescue {}
      state_hash['state'] = 'enable'
      File.open(@state_path, "w:utf-8") { |file| file.puts(state_hash.to_json) }
    end

    def disable
      state_hash = JSON.parse(File.read(@state_path)) rescue {}
      state_hash['state'] = 'disable'
      File.open(@state_path, "w:utf-8") { |file| file.puts(state_hash.to_json) }
    end

    def disabled_in
      state_hash = JSON.parse(File.read(@state_path)) rescue {}
      state_hash['state'] = 'disabled_in'
      state_hash['disabled_in'] = Time.now.to_i + @options[:disabled_in].to_i
      File.open(@state_path, "w:utf-8") { |file| file.puts(state_hash.to_json) }
      puts "disabled_in #{Time.at(state_hash['disabled_in'])}"
    end

    def api_notify_guard
      timestamp= Time.now.strftime('%y%m%d%H%M')
      (@config['api'] || []).each do |api_config|
        response = Sypctl::Http.get(api_config['url'])
        body = response['body'].to_s
        api_state = api_config['keywords']['success'].all? { |keyword| body.downcase.include?(keyword.downcase) }

        api_record_path = File.join(@archived_path, "api-#{Time.now.strftime('%y%m%d')}.json")
        api_record_hash = File.exist?(api_record_path) ? JSON.parse(File.read(api_record_path)) : {}
        api_record_hash[timestamp] = api_state
        api_record_hash["#{timestamp}-api"] = api_config['url']
        File.open(api_record_path, 'w:utf-8') { |file| file.puts(JSON.pretty_generate(api_record_hash)) }
        puts "#{timestamp}, #{api_state ? 'success' : 'failure'}, #{api_config['url']}"

        next if api_state

        # 判断最近十分钟是否有发短信记录，无则发送短信
        sended_notify = check_lastest_sended_notify(api_record_hash)
        next if sended_notify

        api_record_hash, notify_result = api_notify_sender(api_record_hash, api_config, timestamp)
        api_record_hash["#{timestamp}-notify-snapshot"] = api_config.merge(response)
        File.open(api_record_path, 'w:utf-8') { |file| file.puts(JSON.pretty_generate(api_record_hash)) }
      end
    rescue => e
      puts e.message
      puts e.backtrace
    end

    def disk_notify_guard(executed_guard_commands = false)
      timestamp= Time.now.strftime('%y%m%d%H%M')
      disk_notifications = []
      disk_usage_description = Sypctl::Device.disk_usage_description
      (@config['disk'] || []).each do |disk_config|
        disk_usage_hash = disk_usage_description.first { |disk_hash| (disk_hash['MountedOn'] || disk_hash['挂载点']) == disk_config['mountedon'] }
        next unless disk_usage_hash
        
        disk_usage = ((disk_usage_hash['Use%'] || disk_usage_hash['Capacity'] || disk_usage_hash['已用%']).to_s.sub('%', '').to_f/100).round(2)
        puts "#{timestamp}, #{disk_usage < disk_config['threshold'].to_f ? 'ok' : 'boom'}, #{disk_config['mountedon']}, #{disk_usage}"
        next if disk_usage < disk_config['threshold'].to_f
        
        disk_notifications.push("#{disk_config['mountedon']}>=#{disk_usage}")
      end
      return if disk_notifications.empty?

      disk_record_path = File.join(@archived_path, "disk-#{Time.now.strftime('%y%m%d')}.json")
      disk_record_hash = File.exist?(disk_record_path) ? JSON.parse(File.read(disk_record_path)) : {}

      # 判断最近十分钟是否有发短信记录，无则发送短信
      sended_notify = check_lastest_sended_notify(disk_record_hash)
      return if sended_notify

      disk_record_hash, notify_result = disk_notify_sender(disk_record_hash, disk_notifications, timestamp)
      disk_record_hash["#{timestamp}-notify-snapshot"] = disk_usage_description
      File.open(disk_record_path, 'w:utf-8') { |file| file.puts(JSON.pretty_generate(disk_record_hash)) }
    rescue => e
      puts e.message
      puts e.backtrace
    end

    def memory_notify_guard(executed_guard_commands = false)
      timestamp= Time.now.strftime('%y%m%d%H%M')
      memory_usage_description = Sypctl::Device.memory_usage_description
      memory_total = convert_memory_value(memory_usage_description['total'])
      memory_free = convert_memory_value(memory_usage_description['free'])
      memory_usage = ((memory_total - memory_free)*1.0/memory_total).round(2)
      memory_info = memory_usage_description.map { |key, value| [key, value].join(":") }.join(", ")
      
      puts "#{timestamp}, #{memory_usage < @config['memory']['threshold'] ? 'ok' : 'boom'}, memory, #{memory_usage}"
      return if memory_usage < @config['memory']['threshold'].to_f

      memory_record_path = File.join(@archived_path, "memory-#{Time.now.strftime('%y%m%d')}.json")
      memory_record_hash = File.exist?(memory_record_path) ? JSON.parse(File.read(memory_record_path)) : {}

      # 判断最近十分钟是否有发短信记录，无则发送短信
      sended_notify = check_lastest_sended_notify(memory_record_hash)
      return if sended_notify

      # 若配置有清理内存的命令，则执行该命令，然后重新监测内存状态
      if !executed_guard_commands && @config['memory']['guard_commands']
        @config['memory']['guard_commands'].each do |command|
          `#{command}` rescue 'ignore'
        end

        memory_notify_guard(true)
        return
      end
      
      memory_record_hash, notify_result = memory_notify_sender(memory_record_hash, memory_usage, memory_info, timestamp)
      memory_record_hash["#{timestamp}-notify-snapshot"] = memory_usage_description
      memory_record_hash["#{timestamp}-memory-snapshot"] = Sypctl::Device.top_memory_snapshot
      File.open(memory_record_path, 'w:utf-8') { |file| file.puts(JSON.pretty_generate(memory_record_hash)) }
    rescue => e
      puts e.message
      puts e.backtrace
    end

    def render
      puts JSON.pretty_generate(@config)
    end

    def guard
      api_notify_guard if @config['api']
      disk_notify_guard if @config['disk']
      memory_notify_guard if @config['memory']
    end

    def list(offset_date = 0)
      ['api', 'disk', 'memory'].each do |type|
        date = (Time.now-offset_date*24*60*60).strftime('%y%m%d')
        path = File.join(@archived_path, "#{type}-#{date}.json")
        unless File.exist?(path)
          puts "#{date}, #{type.upcase} 异常列表为空."
          next
        end

        puts "#{type} 监控列表:(#{date})"
        puts "Path: #{path}"
        puts JSON.pretty_generate(JSON.parse(File.read(path)))
      end
    end

    def method_missing(method_name, arg = nil)
      if m = method_name.to_s.match(/list_(\d+)/)
        list(m[1].to_i)
      else
        super
      end
    end

    protected

    def api_notify_sender(api_record_hash, api_config, timestamp)
      if @notify_type == 'sms'
        notify_options = JSON.parse(@config['sms-config'].to_json) # deep clone
        notify_options['mobiles'] = notify_options['mobiles'].map { |record| record['mobile'] }
        notify_options['template_options'] = notify_options['template_options'].sub('${project}', api_config['project']).sub('${message}', "API响应(#{Time.now.strftime('%H:%M')})")
        notify_result = Aliyun::Sms.send_guard_nofity(notify_options)
        api_record_hash["#{timestamp}-sms"] = true
        api_record_hash["#{timestamp}-sms-result"] = notify_result
      elsif @notify_type == 'webhook'
        notify_options = @config['webhook-config']
        notify_options['keys'].each do |config|
          payload_options = {
            msgtype: 'markdown',
            markdown: {
              content: [
                "监控到API响应异常，请相关同事处理。",
                "> API: <font color=\"warning\">#{api_config['url']}</font>",
                "> 时间点: <font color=\"comment\">#{Time.now.strftime('%y/%m/%d %H:%M:%S')}</font>",
                "> 监测站: <font color=\"info\">#{@config['project']}</font>"
              ].join("\n")
            }
          }
          notify_result = QyWeixin::Webhook.send_guard_nofity(config['key'], payload_options)
          api_record_hash["#{timestamp}-#{config['key']}"] = true
          api_record_hash["#{timestamp}-#{config['key']}-result"] = notify_result
        end
      else
        notify_result = {error: "未知通知类型#{@notify_type}"}
      end
      return [api_record_hash, notify_result]
    end

    def disk_notify_sender(disk_record_hash, disk_notifications, timestamp)
      if @notify_type == 'sms'
        notify_options = JSON.parse(@config['sms-config'].to_json) # deep clone
        notify_options['mobiles'] = notify_options['mobiles'].map { |record| record['mobile'] }
        notify_options['template_options'] = notify_options['template_options'].sub('${project}', @config['project']).sub('${message}', "磁盘#{disk_notifications.join(',')}(#{Time.now.strftime('%H:%M')})"[0..19])
        notify_result = Aliyun::Sms.send_guard_nofity(notify_options)
        disk_record_hash["#{timestamp}-sms"] = true
        disk_record_hash["#{timestamp}-sms-result"] = notify_result
      elsif @notify_type == 'webhook'
        disk_notifications = disk_notifications.map { |line| ">挂载点: <font color=\"warning\">#{line}</font>" }
        disk_notifications.push("> 时间点: <font color=\"comment\">#{Time.now.strftime('%y/%m/%d %H:%M:%S')}</font>")
        disk_notifications.push("> 服务器: <font color=\"info\">#{@config['project']}</font>")

        notify_options = @config['webhook-config']
        notify_options['keys'].each do |config|
          payload_options = {
            msgtype: 'markdown',
            markdown: {
              content: "磁盘使用超出监控阀值，请相关同事处理。\n" + disk_notifications.join("\n")
            }
          }
          notify_result = QyWeixin::Webhook.send_guard_nofity(config['key'], payload_options)
          disk_record_hash["#{timestamp}-#{config['key']}"] = true
          disk_record_hash["#{timestamp}-#{config['key']}-result"] = notify_result
        end
        disk_record_hash["#{timestamp}-webhook"] = true
      else
        notify_result = {error: "未知通知类型#{@notify_type}"}
      end
      return [disk_record_hash, notify_result]
    end

    def memory_notify_sender(memory_record_hash, memory_usage, memory_info, timestamp)
      if @notify_type == 'sms'
        notify_options = JSON.parse(@config['sms-config'].to_json) # deep clone
        notify_options['mobiles'] = notify_options['mobiles'].map { |record| record['mobile'] }
        notify_options['template_options'] = notify_options['template_options'].sub('${project}', @config['project']).sub('${message}', ("内存>#{memory_usage}(#{Time.now.strftime('%H:%M')})")[0..19])
        notify_result = Aliyun::Sms.send_guard_nofity(notify_options)
        memory_record_hash["#{timestamp}-sms"] = true
        memory_record_hash["#{timestamp}-sms-result"] = notify_result
      elsif @notify_type == 'webhook'
        memory_notifications = [
          "> 内存值: <font color=\"warning\">>= #{memory_usage}</font>",
          "> 详细值: <font color=\"comment\"> #{memory_info}</font>",
          "> 时间点: <font color=\"comment\">#{Time.now.strftime('%y/%m/%d %H:%M:%S')}</font>",
          "> 服务器: <font color=\"info\">#{@config['project']}</font>"
        ]

        notify_options = @config['webhook-config']
        notify_options['keys'].each do |config|
          payload_options = {
            msgtype: 'markdown',
            markdown: {
              content: "内存使用超出监控阀值，请相关同事处理。\n" + memory_notifications.join("\n")
            }
          }
          notify_result = QyWeixin::Webhook.send_guard_nofity(config['key'], payload_options)
          memory_record_hash["#{timestamp}-#{config['key']}"] = true
          memory_record_hash["#{timestamp}-#{config['key']}-result"] = notify_result
        end
      else
        notify_result = {error: "未知通知类型#{@notify_type}"}
      end
      return [memory_record_hash, notify_result]
    end

    def convert_memory_value(value)
      convert_hash = {
        G: 1024*1024,
        M: 1024,
        K: 1
      }
      convert_hash.keys.each do |key|
        next unless value.to_s.include?(key.to_s)
        value = value.to_s.sub(key.to_s, '').to_i * convert_hash[key]
      end
      value.to_f
    end

    def check_lastest_sended_notify(record_hash)
      # 判断最近十分钟是否有发短信记录，无则发送短信
      sended_notify = (1..10).to_a.any? do |interval|
        date = Time.now - interval*60
        record_hash["#{date.strftime('%y%m%d%H%M')}-sms"] == true
      end
    end

    def check_notify_type
      notify_type = @config['notify-type']
      supported_types = ['sms', 'webhook']
      if !notify_type
        puts 'warning: 未配置 notify-type, 使用默认值 sms'
        return 'sms'
      elsif !supported_types.include?(notify_type)
        puts "warning: 不支持的 notify-type 类型 - #{notify_type}, 使用默认值 sms"
        return 'sms'
      else
        puts "notify-type: #{notify_type}"
        return notify_type
      end
    end
  end
end

Notify.options(options)
Notify.send(options.keys.first)

