# encoding: utf-8
require 'json'

config = JSON.parse(File.read('sendmail.json.example'))

config['subject'] = '自定义标题'
config['body'] = File.read('logs/2019-10-22.log')

cached_config = "logs/sendmail.#{Time.now.strftime('%y%m%d%H%M%S')}.json"
File.open(cached_config, 'w:utf-8') do |file|
  file.puts(config.to_json)
end

cached_path = File.expand_path("../#{cached_config}", __FILE__)
puts "sypctl sendmail --file #{cached_path}"
