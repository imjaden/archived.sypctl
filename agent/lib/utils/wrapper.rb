# encoding: utf-8
require 'optparse'
require File.expand_path('../mysql.rb', __FILE__)
require File.expand_path('../device.rb', __FILE__)


options = {}
option_parser = OptionParser.new do |opts|
  options[:mysql_report] = false
  opts.on('-m', "--mysql-report", 'MySQL运行状态报告') do |value|
    options[:mysql_report] = true
  end
  options[:device_report] = false
  opts.on('-d', "--device-report", '设备运行状态报告') do |value|
    options[:device_report] = true
  end
end.parse! rescue {}

Sypctl::MySQL.print_report if options[:mysql_report]
Sypctl::Device.print_report if options[:device_report]
