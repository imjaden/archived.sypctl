#!/bin/ruby
# encoding: utf-8
########################################
#
#  SypETL Manager v1.0
#
########################################
#
# 开发人员: Jaden
# 更新日期: 2019-10-30
# 功能模块: 调用ETL流脚本、归档日志、邮件通知
# 代码步骤:
#   1. 约定ETL流脚本目录，以脚本名称为作参数
#   2. 检测脚本配置项
#   2. 约定脚本目录 /data/work/scripts/, 调用脚本并重定向日志
#   3. 根据脚本退出码(0 表示成功，其他表示失败)判断运行是否成功
#   4. 发送邮件，附件日志文件
#
require 'json'
require 'timeout'
require 'optparse'
require 'colorize'
require File.expand_path('../../../agent/lib/utils/qyweixin_webhook', __FILE__)

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: service-tools.rb [args]"
  opts.on('-h', '--help', '参数说明') do
    puts "服务进程管理脚本"
    puts opts
    exit
  end
  options[:execute] = false
  opts.on('-e', "--execute", '执行脚本') do |value|
    options[:execute] = true
    options[:check] = false
  end
  options[:check] = true
  opts.on('-c', "--check", '检测脚本') do |value|
    options[:check] = true
    options[:execute] = false
  end
  opts.on('-a', "--companyname companyname", '公司名称') do |value|
    options[:companyname] = value
  end
  opts.on('-b', "--modulename modulename", '模块名称') do |value|
    options[:modulename] = value
  end
  options[:list] = false
  opts.on('-l', "--list", '模块列表') do |value|
    options[:list] = true
  end
  options[:label] = 'sypetl'
  opts.on('-b', "--label label", '列表标签') do |value|
    options[:label] = value
  end
end.parse!
@options = options

def action_list_modules
  module_list = Dir.glob("/data/work/scripts/*/*/tools.sh").to_a
  puts "模块扫描: (#{module_list.length})"
  module_list.each do |module_path|
    parts = module_path.scan(/\/data\/work\/scripts\/(.*?)\/(.*?)\/tools.sh/).flatten.join(' ')
    puts "#{@options[:label]} #{parts}"
  end
end

def timestamp
  Time.now.strftime('%y%m%d%H%M%S')
end

if @options[:list]
  action_list_modules
  exit
end

puts `ruby #{__FILE__} -h` if options.keys.empty?

log_folder = "/data/work/logs"
script_folder = "/data/work/scripts"
@options[:logpath] = "#{log_folder}/#{options[:companyname]}-#{options[:modulename]}-#{timestamp}.log"
@options[:reportpath] = "#{log_folder}/#{options[:companyname]}-#{options[:modulename]}-#{timestamp}.report"
@options[:scriptpath] = File.join(script_folder, options[:companyname], options[:modulename], "tools.sh")
@options[:mailconfig] = "/data/work/config/sypetl-sendmail.json"
@options[:subject] = "脚本业务标题"

def logger(message = '')
  output = Time.now.strftime("%y/%m/%d %H:%M:%S - #{message}")
  `echo "#{output}" >> #{@options[:logpath]} 2>&1`
  puts output
end

unless File.exists?(@options[:scriptpath])
  puts("Error: 脚本不存在 - #{@options[:scriptpath]}".colorize(:yellow))
  exit(1)
end

def action_check_script
  strict_keywords = [
    '^# 开发人员:',
    '^# 更新日期:',
    '^# 客户名称:',
    '^# 业务模块:',
    '^# 定时任务:',
    '^# 对接团队:',
    '^# 业务描述:',
    '^set -e'
  ]
  script_content = File.read(@options[:scriptpath])
  puts("检测时间: #{Time.now.strftime('%y-%m-%d %H:%M:%S')}")
  puts("公司名称: #{@options[:companyname]}")
  puts("模块名称: #{@options[:modulename]}")
  puts("脚本入口: #{@options[:scriptpath]}")
  puts("检测必填项:")
  strict_keywords.each do |keyword|
    if keyword == '^set -e'
      unset_set_e = script_content.scan(/#{keyword}/).flatten.size.zero?
      if unset_set_e
        puts("- 脚本模式: " + "未配置 `set -e`".colorize(:yellow))
        # exit(1)
      else
        puts("- 脚本模式: " + "`set -e`".colorize(:green))
      end
    else
      scaned_descriptions = script_content.scan(Regexp.new("#{keyword}\s?(.*?)$")).flatten
      if scaned_descriptions.size.zero?
        puts("- 配置错误: `#{keyword}`，中止后续操作".colorize(:yellow))
        exit(1)
      else
        @options[:subject] = scaned_descriptions[0].to_s.strip if keyword.include?("业务模块")
        puts("- #{keyword.sub('^# ', '')} #{scaned_descriptions[0].colorize(:green)}")
      end
    end
  end
end

def action_execute_script
  `echo >> #{@options[:logpath]} 2>&1`
  `echo "$ bash #{@options[:scriptpath]} >> #{@options[:logpath]} 2>&1" >> #{@options[:logpath]} 2>&1`
  `echo >> #{@options[:logpath]} 2>&1`
  `echo "开始, 脚本执行" >> #{@options[:logpath]} 2>&1`
  `bash #{@options[:scriptpath]} >> #{@options[:logpath]} 2>&1`
  `echo "结束, 脚本执行" >> #{@options[:logpath]} 2>&1`
  `echo >> #{@options[:logpath]} 2>&1`
  logger "日志路径: #{@options[:logpath]}"
  logger "报表路径: #{@options[:reportpath]}"

  action_generate_report
  action_push_notify_when_error
  action_sendmail_script
end

# 判断任务执行失败：
# 1. 日志文件不存在
# 2. 日志文件内容为空
# 3. 日志内容包含 ERROR
def _action_check_logstate
  return "失败" unless File.exists?(@options[:logpath])
  content = File.read(@options[:logpath]).strip
  return "失败" if content.empty?
  return "失败" if content.include?("ERROR")
  return "成功"
end

def action_generate_report
  @options[:report] = {
    state: _action_check_logstate,
    subject: @options[:subject],
    timestamp: timestamp,
    companyname: @options[:companyname],
    modulename: @options[:modulename],
    scriptpath: @options[:scriptpath],
    logpath: @options[:logpath],
  }
  File.open(@options[:reportpath], 'w:utf-8') { |file| file.puts(@options[:report].to_json) }
  return @options[:report]
end

def action_push_notify_when_error
  return if _action_check_logstate == '成功'
  notify_path = "/etc/sypctl/notify.json"
  return unless File.exists?(notify_path)
  notify_config = JSON.parse(File.read(notify_path))
  return unless notify_options = notify_config['webhook-config']

  payload_options = {
    msgtype: 'markdown',
    markdown: {
      content: [
        "ETL 任务执行[失败], 请及时处理！",
        "> 任务名称: <font color=\"warning\">#{@options[:subject]}</font>",
        "> 客户公司: <font color=\"info\">#{@options[:companyname]}</font>",
        "> 业务模块: <font color=\"info\">#{@options[:modulename]}</font>",
        "> 脚本路径: <font color=\"comment\">#{@options[:scriptpath]}</font>",
        "> 日志路径: <font color=\"comment\">#{@options[:logpath]}</font>",
      ].join("\n")
    }
  }
  notify_options['keys'].each do |config|
    QyWeixin::Webhook.send_guard_nofity(config['key'], payload_options)
  end
end

def action_sendmail_script
  cached_config = "/data/work/logs/sendmail.#{timestamp}.json"
  logger "邮件配置: #{cached_config}"
  
  config = JSON.parse(File.read(@options[:mailconfig]))
  config['subject'] = "[#{_action_check_logstate}]#{@options[:subject]}"
  config['attachment'] = @options[:logpath]
  config['body'] = <<-EOF
<style>
pre, code {
  display: block;
  background: none repeat scroll 0 0;
  background-color: #002b36;
  border-radius: 4px 4px 4px 4px;
  box-shadow: rgba(0, 0, 0, 0.25) 0px 0px 10px inset;
  clear: both;
  font-family: 'Consolas', 'Courier', 'Monaco', monospace;
  color: #93a1a1;
  margin: 5px 0px;
  overflow: auto;
  padding: 10px;
  white-space: pre;
}
</style>
<pre>
#{JSON.pretty_generate(@options[:report])}
</pre>
EOF

  File.open(cached_config, 'w:utf-8') { |file| file.puts(config.to_json) }
  logger `sypctl sendmail --file #{cached_config}`
end

action_check_script

exit unless options[:execute]
action_execute_script
