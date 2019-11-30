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

config_path = "/etc/sypctl/sms-guard.json"
exit(1) unless File.exists?(config_path)

config = JSON.parse(File.read(config_path))
sms_guard_path = File.join(ENV['SYPCTL_HOME'], 'agent/db/sms-guard')
archived_path = File.join(sms_guard_path, 'archived')
FileUtils.mkdir_p(archived_path) unless File.exists?(archived_path)

def api_sms_guard(config, archived_path)
  timestamp= Time.now.strftime('%y%m%d%H%M')
  (config['api'] || []).each do |api_config|
    response = Sypctl::Http.get(api_config['url'])
    body = response['body'].to_s
    api_state = api_config['keywords']['success'].all? { |keyword| body.include?(keyword) }

    api_record_path = File.join(archived_path, "api-#{Digest::MD5.hexdigest(api_config['url'])}-#{Time.now.strftime('%y%m%d')}.json")
    api_record_hash = File.exists?(api_record_path) ? JSON.parse(File.read(api_record_path)) : {}
    api_record_hash[timestamp] = api_state
    File.open(api_record_path, 'w:utf-8') { |file| file.puts(JSON.pretty_generate(api_record_hash)) }
    puts "#{timestamp}, #{api_state ? 'success' : 'failure'}, #{api_config['url']}"

    next if api_state

    # 判断最近十分钟是否有发短信记录，无则发送短信
    sended_sms = (1..10).to_a.any? do |interval|
      date = Time.now - interval*60
      api_record_hash["#{date.strftime('%y%m%d%H%M')}-sms"] == true
    end

    next if sended_sms

    aliyun_sms_options = JSON.parse(config['aliyun_sms'].to_json) # deep clone
    aliyun_sms_options['mobiles'] = config['mobiles'].map { |record| record['mobile'] }
    aliyun_sms_options['template_options'] = aliyun_sms_options['template_options'].sub('${project}', api_config['project']).sub('${message}', 'API响应')
    aliyun_sms_result = Aliyun::Sms.send_guard_nofity(aliyun_sms_options)

    api_record_hash["#{timestamp}-sms"] = true
    api_record_hash["#{timestamp}-sms-result"] = aliyun_sms_result
    File.open(api_record_path, 'w:utf-8') { |file| file.puts(JSON.pretty_generate(api_record_hash)) }
  end
rescue => e
  puts e.message
  puts e.backtrace
end

def disk_sms_guard(config, archived_path)
  timestamp= Time.now.strftime('%y%m%d%H%M')
  disk_notifications = []
  disk_usage_description = Sypctl::Device.disk_usage_description
  (config['disk'] || []).each do |disk_config|
    disk_usage_hash = disk_usage_description.first { |config| (config['MountedOn'] || config['挂载点']) == disk_config['mountedon'] }
    next unless disk_usage_hash
    
    disk_usage = (disk_usage_hash['Use%'] || disk_usage_hash['Capacity'] || disk_usage_hash['已用%']).to_s.sub('%', '').to_f/100
    puts "#{timestamp}, #{disk_usage < disk_config['threshold'].to_f ? 'ok' : 'boom'}, #{disk_config['mountedon']}, #{disk_usage}"
    next if disk_usage < disk_config['threshold'].to_f
    
    disk_notifications.push("磁盘#{disk_config['mountedon']}>=#{disk_config['threshold']}")
  end
  return if disk_notifications.empty?

  disk_record_path = File.join(archived_path, "disk-#{Time.now.strftime('%y%m%d')}.json")
  disk_record_hash = File.exists?(disk_record_path) ? JSON.parse(File.read(api_record_path)) : {}

  # 判断最近十分钟是否有发短信记录，无则发送短信
  sended_sms = (1..10).to_a.any? do |interval|
    date = Time.now - interval*60
    disk_record_hash["#{date.strftime('%y%m%d%H%M')}-sms"] == true
  end

  return if sended_sms

  disk_notifications = ['磁盘超出空间']
  aliyun_sms_options = JSON.parse(config['aliyun_sms'].to_json) # deep clone
  aliyun_sms_options['mobiles'] = config['mobiles'].map { |record| record['mobile'] }
  aliyun_sms_options['template_options'] = aliyun_sms_options['template_options'].sub('${project}', config['project']).sub('${message}', disk_notifications.join(','))
  aliyun_sms_result = Aliyun::Sms.send_guard_nofity(aliyun_sms_options)

  disk_record_hash["#{timestamp}-sms"] = true
  disk_record_hash["#{timestamp}-sms-result"] = aliyun_sms_result
  File.open(disk_record_path, 'w:utf-8') { |file| file.puts(JSON.pretty_generate(disk_record_hash)) }
rescue => e
  puts e.message
  puts e.backtrace
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

def memory_sms_guard(config, archived_path)
  timestamp= Time.now.strftime('%y%m%d%H%M')
  memory_usage_description = Sypctl::Device.memory_usage_description
  memory_total = convert_memory_value(memory_usage_description['total'])
  memory_free = convert_memory_value(memory_usage_description['used'])
  memory_usage = ((memory_total - memory_free)*1.0/memory_total).round(2)
  
  puts "#{timestamp}, #{memory_usage < config['memory'] ? 'ok' : 'boom'}, memory, #{memory_usage}"
  return if memory_usage < config['memory']

  memory_record_path = File.join(archived_path, "memory-#{Time.now.strftime('%y%m%d')}.json")
  memory_record_hash = File.exists?(memory_record_path) ? JSON.parse(File.read(memory_record_path)) : {}

  # 判断最近十分钟是否有发短信记录，无则发送短信
  sended_sms = (1..10).to_a.any? do |interval|
    date = Time.now - interval*60
    memory_record_hash["#{date.strftime('%y%m%d%H%M')}-sms"] == true
  end

  return if sended_sms

  aliyun_sms_options = JSON.parse(config['aliyun_sms'].to_json) # deep clone
  aliyun_sms_options['mobiles'] = config['mobiles'].map { |record| record['mobile'] }
  aliyun_sms_options['template_options'] = aliyun_sms_options['template_options'].sub('${project}', config['project']).sub('${message}', "内存>=#{config['memory']}")
  aliyun_sms_result = Aliyun::Sms.send_guard_nofity(aliyun_sms_options)

  memory_record_hash["#{timestamp}-sms"] = true
  memory_record_hash["#{timestamp}-sms-result"] = aliyun_sms_result
  File.open(memory_record_path, 'w:utf-8') { |file| file.puts(JSON.pretty_generate(memory_record_hash)) }
rescue => e
  puts e.message
  puts e.backtrace
end

api_sms_guard(config, archived_path) if config['api']
disk_sms_guard(config, archived_path) if config['disk']
memory_sms_guard(config, archived_path) if config['memory']
