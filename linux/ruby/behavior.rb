# encoding: utf-8

require 'json'
require 'timeout'
require 'optparse'
require File.expand_path('../../../agent/lib/utils/http', __FILE__)
require File.expand_path('../../../agent/lib/utils/device', __FILE__)
require File.expand_path('../../../agent/lib/core_ext/numberic', __FILE__)

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: service-tools.rb [args]"
  opts.on('-h', '--help', '参数说明') do
    puts "behavior utils"
    puts opts
    exit 1
  end
  opts.on('-o', "--old version", 'old version') do |value|
    options[:old] = value
  end
  opts.on('-n', "--new version", 'new version') do |value|
    options[:new] = value
  end
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

ENV["SYPCTL_API"] = ENV["SYPCTL_API_CUSTOM"] || "http://sypctl.com"
Sypctl::Http.post_behavior({
  behavior: "升级 sypctl 代理版本 #{options[:old]} 至 #{options[:new]}", 
  object_type: 'agent', 
  object_id: "upgrade"
}, {}, {print_log: false})
