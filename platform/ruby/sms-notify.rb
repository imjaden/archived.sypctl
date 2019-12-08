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

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: sms-notify.rb [args]"
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
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

config_path = "/etc/sypctl/sms-notify.json"
unless File.exists?(config_path)
  puts "Error: not found #{config_path}"
  exit(1)
end 

class SmsNotify
  class << self
    def options(config_path)
      @config = JSON.parse(File.read(config_path))
      @archived_path = File.join(ENV['SYPCTL_HOME'], 'agent/db/sms-notify', 'archived')
      FileUtils.mkdir_p(@archived_path) unless File.exists?(@archived_path)
    end

    def api_sms_guard
      timestamp= Time.now.strftime('%y%m%d%H%M')
      (@config['api'] || []).each do |api_config|
        response = Sypctl::Http.get(api_config['url'])
        body = response['body'].to_s
        api_state = api_config['keywords']['success'].all? { |keyword| body.include?(keyword) }

        api_record_path = File.join(@archived_path, "api-#{Digest::MD5.hexdigest(api_config['url'])}-#{Time.now.strftime('%y%m%d')}.json")
        api_record_hash = File.exists?(api_record_path) ? JSON.parse(File.read(api_record_path)) : {}
        api_record_hash[timestamp] = api_state
        File.open(api_record_path, 'w:utf-8') { |file| file.puts(JSON.pretty_generate(api_record_hash)) }
        puts "#{timestamp}, #{api_state ? 'success' : 'failure'}, #{api_config['url']}"

        next if api_state

        # 判断最近十分钟是否有发短信记录，无则发送短信
        sended_sms = check_lastest_sended_sms(api_record_hash)
        next if sended_sms

        aliyun_sms_options = JSON.parse(@config['aliyun_sms'].to_json) # deep clone
        aliyun_sms_options['mobiles'] = @config['mobiles'].map { |record| record['mobile'] }
        aliyun_sms_options['template_options'] = aliyun_sms_options['template_options'].sub('${project}', api_config['project']).sub('${message}', "API响应(#{Time.now.strftime('%H:%M')})")
        aliyun_sms_result = Aliyun::Sms.send_guard_nofity(aliyun_sms_options)

        api_record_hash["#{timestamp}-sms"] = true
        api_record_hash["#{timestamp}-sms-result"] = aliyun_sms_result
        api_record_hash["#{timestamp}-notify-snapshot"] = api_config.merge(response)
        File.open(api_record_path, 'w:utf-8') { |file| file.puts(JSON.pretty_generate(api_record_hash)) }
      end
    rescue => e
      puts e.message
      puts e.backtrace
    end

    def disk_sms_guard(executed_guard_commands = false)
      timestamp= Time.now.strftime('%y%m%d%H%M')
      disk_notifications = []
      disk_usage_description = Sypctl::Device.disk_usage_description
      (@config['disk'] || []).each do |disk_config|
        disk_usage_hash = disk_usage_description.first { |disk_hash| (disk_hash['MountedOn'] || disk_hash['挂载点']) == disk_config['mountedon'] }
        next unless disk_usage_hash
        
        disk_usage = ((disk_usage_hash['Use%'] || disk_usage_hash['Capacity'] || disk_usage_hash['已用%']).to_s.sub('%', '').to_f/100).round(2)
        puts "#{timestamp}, #{disk_usage < disk_config['threshold'].to_f ? 'ok' : 'boom'}, #{disk_config['mountedon']}, #{disk_usage}"
        next if disk_usage < disk_config['threshold'].to_f
        
        disk_notifications.push("#{disk_config['mountedon']}>#{disk_usage}")
      end
      return if disk_notifications.empty?

      disk_record_path = File.join(@archived_path, "disk-#{Time.now.strftime('%y%m%d')}.json")
      disk_record_hash = File.exists?(disk_record_path) ? JSON.parse(File.read(disk_record_path)) : {}

      # 判断最近十分钟是否有发短信记录，无则发送短信
      sended_sms = check_lastest_sended_sms(disk_record_hash)
      return if sended_sms

      aliyun_sms_options = JSON.parse(@config['aliyun_sms'].to_json) # deep clone
      aliyun_sms_options['mobiles'] = @config['mobiles'].map { |record| record['mobile'] }
      aliyun_sms_options['template_options'] = aliyun_sms_options['template_options'].sub('${project}', @config['project']).sub('${message}', "磁盘#{disk_notifications.join(',')}(#{Time.now.strftime('%H:%M')})"[0..19])
      aliyun_sms_result = Aliyun::Sms.send_guard_nofity(aliyun_sms_options)

      disk_record_hash["#{timestamp}-sms"] = true
      disk_record_hash["#{timestamp}-sms-result"] = aliyun_sms_result
      disk_record_hash["#{timestamp}-notify-snapshot"] = disk_usage_description
      File.open(disk_record_path, 'w:utf-8') { |file| file.puts(JSON.pretty_generate(disk_record_hash)) }
    rescue => e
      puts e.message
      puts e.backtrace
    end

    def memory_sms_guard(executed_guard_commands = false)
      timestamp= Time.now.strftime('%y%m%d%H%M')
      memory_usage_description = Sypctl::Device.memory_usage_description
      memory_total = convert_memory_value(memory_usage_description['total'])
      memory_free = convert_memory_value(memory_usage_description['free'])
      memory_usage = ((memory_total - memory_free)*1.0/memory_total).round(2)
      
      puts "#{timestamp}, #{memory_usage < @config['memory']['threshold'] ? 'ok' : 'boom'}, memory, #{memory_usage}"
      return if memory_usage < @config['memory']['threshold'].to_f

      memory_record_path = File.join(@archived_path, "memory-#{Time.now.strftime('%y%m%d')}.json")
      memory_record_hash = File.exists?(memory_record_path) ? JSON.parse(File.read(memory_record_path)) : {}

      # 判断最近十分钟是否有发短信记录，无则发送短信
      sended_sms = check_lastest_sended_sms(memory_record_hash)
      return if sended_sms

      # 若配置有清理内存的命令，则执行该命令，然后重新监测内存状态
      if !executed_guard_commands && @config['memory']['guard_commands']
        @config['memory']['guard_commands'].each do |command|
          `#{command}` rescue 'ignore'
        end

        memory_sms_guard(true)
      end

      aliyun_sms_options = JSON.parse(@config['aliyun_sms'].to_json) # deep clone
      aliyun_sms_options['mobiles'] = @config['mobiles'].map { |record| record['mobile'] }
      aliyun_sms_options['template_options'] = aliyun_sms_options['template_options'].sub('${project}', @config['project']).sub('${message}', ("内存>#{memory_usage}(#{Time.now.strftime('%H:%M')})")[0..19])
      aliyun_sms_result = Aliyun::Sms.send_guard_nofity(aliyun_sms_options)

      memory_record_hash["#{timestamp}-sms"] = true
      memory_record_hash["#{timestamp}-sms-result"] = aliyun_sms_result
      memory_record_hash["#{timestamp}-notify-snapshot"] = memory_usage_description
      File.open(memory_record_path, 'w:utf-8') { |file| file.puts(JSON.pretty_generate(memory_record_hash)) }
    rescue => e
      puts e.message
      puts e.backtrace
    end

    def render
      puts JSON.pretty_generate(@config)
    end

    def guard
      api_sms_guard if @config['api']
      disk_sms_guard if @config['disk']
      memory_sms_guard if @config['memory']
    end

    def list(offset_date = 0)
      ['api', 'disk', 'memory'].each do |type|
        date = (Time.now-offset_date*24*60*60).strftime('%y%m%d')
        path = File.join(@archived_path, "#{type}-#{date}.json")
        unless File.exists?(path)
          puts "#{date}, #{type.upcase} 异常列表为空."
          next
        end

        puts "#{type} 监控列表:(#{date})"
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

    def check_lastest_sended_sms(record_hash)
      # 判断最近十分钟是否有发短信记录，无则发送短信
      sended_sms = (1..10).to_a.any? do |interval|
        date = Time.now - interval*60
        record_hash["#{date.strftime('%y%m%d%H%M')}-sms"] == true
      end
    end
  end
end

SmsNotify.options(config_path)
SmsNotify.send(options.keys.first)

