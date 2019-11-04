# encoding: utf-8
########################################
#  
#  Send Mail v1.0
#
########################################
#
# 具体用法:
# $ ruby mail-tools.rb --help
# 
require 'json'
require 'timeout'
require 'optparse'
require 'mail'
require File.expand_path('../../../agent/lib/core_ext/hash', __FILE__)

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: service-tools.rb [args]"
  opts.on('-h', '--help', '参数说明') do
    puts "服务进程管理脚本"
    puts opts
    exit
  end

  opts.on('f', "--file filepath", '读取配置档') do |value|
    options[:file] = value
  end

  options[:script] = false
  opts.on('s', "--script", '脚本示例') do |value|
    options[:script] = true
  end

  # opts.on('', "--subject subject", '邮件标题') do |value|
  #   options[:subject] = value
  # end
  # opts.on('', "--from from-email", '发件人') do |value|
  #   options[:from] = value
  # end
  # opts.on('', "--to to-list", '收件人列表') do |value|
  #   options[:to] = value
  # end
  # opts.on('', "--smtp smtp-config", 'SMTP 配置') do |value|
  #   options[:smtp] = value
  # end
  # opts.on('', "--interval interval", '发送时间间隔') do |value|
  #   options[:interval] = value
  # end
end.parse!
options[:interval] ||= 0

if options[:script]
  puts "ScriptPath:"
  puts File.expand_path("../sypctl-sendmail.rb", __FILE__)
  exit
end

if !options[:file] || !File.exists?(options[:file])
  puts `ruby #{__FILE__} -h` if options.keys.empty?
  puts "Error: 请提供配置档路径！"
  exit
end

file_config = JSON.parse(File.read(options[:file])).deep_symbolize_keys

subject = file_config[:subject]
to_list = file_config[:to]
from_email = file_config[:from]
mail_body = file_config[:body]
mail_content_type = file_config[:content_type] || 'text/html; charset=UTF-8'
attacment = file_config[:attacment]
smtp_config = file_config[:smtp]

to_list.each do |to_email|
  mail = Mail.new do
    from    from_email
    to      to_email
    subject subject
    html_part do
      content_type mail_content_type
      body mail_body
    end

    add_file attacment if attacment
  end
  mail.delivery_method :smtp, smtp_config
  mail.raise_delivery_errors = true

  begin
    response = mail.deliver!
    puts "#{subject}, #{from_email} -> #{to_email}, status: #{response.status}"
  rescue => e
    puts "#{subject}, #{from_email} -> #{to_email}, status: exception, string: #{e.message}"
    puts e.backtrace
  end
end