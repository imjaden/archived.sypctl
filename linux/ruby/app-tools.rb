# encoding: utf-8
########################################
#  
#  Service Manager v1.0
#
########################################
#
# 具体用法:
# $ ruby app-tools.rb --help
# 
require 'json'
require 'timeout'
require 'optparse'
require 'fileutils'
require 'terminal-table'

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: app-tools.rb [args]"
  opts.on('-h', '--help', '参数说明') do
    puts "应用版本管理脚本"
    puts opts
    exit
  end
  options[:init] = false
  opts.on('-i', "--init", '查看管理的服务列表') do |value|
    options[:init] = true
  end
  opts.on('-k', "--key key", '部署时使用的配置key') do |value|
    options[:key] = value
  end
  opts.on('-v', "--value value", '部署时使用的配置value') do |value|
    options[:value] = value
  end
  options[:deploy] = false
  opts.on('-d', "--deploy", '执行部署操作') do |value|
    options[:deploy] = true
  end
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

class App
  class << self
    def options(options)
      @options = options

      json_path = "/etc/sypctl/app.json"
      unless File.exists?(json_path)
        puts "Error: 配置档不存在，请创建并配置 /etc/sypctl/app.json\n退出操作"
        exit 1
      end
    end

    def init()
    end

    def config()
    end

    def deploy()
    end
  end
end

App.options(options)
App.send(options.keys.first)
