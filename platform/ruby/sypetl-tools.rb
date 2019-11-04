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

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: service-tools.rb [args]"
  opts.on('-h', '--help', '参数说明') do
    puts "服务进程管理脚本"
    puts opts
    exit
  end
  options[:execute] = false
  opts.on('-e', "--execute", '执行脚本代码') do |value|
    options[:execute] = true
    options[:check] = false
  end
  options[:check] = true
  opts.on('-c', "--check", '检测脚本配置') do |value|
    options[:check] = true
    options[:execute] = false
  end
  opts.on('-a', "--companyname companyname", '公司名称') do |value|
    options[:companyname] = value
  end
  opts.on('-b', "--modulename modulename", '模块名称') do |value|
    options[:modulename] = value
  end
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

def logger(message = '')
  output = Time.now.strftime("%y/%m/%d %H:%M:%S - #{message}")
  `echo "#{output}" >> #{@log_path} 2>&1`
  puts output
end

script_name = options[:filepath]
log_folder = "/data/work/logs"
script_folder = "/data/work/scripts"
@log_path = "#{log_folder}/#{options[:companyname]}-#{options[:modulename]}-#{Time.now.strftime('%y%m%d%H%M%S')}.log"
@script_path = File.join(script_folder, options[:companyname], options[:modulename], "tools.sh")
@sendmail_config = "/data/work/config/sypetl-sendmail.json"
@script_subject = "脚本业务标题"

unless File.exists?(@script_path)
  logger("脚本不存在:\n#{@script_path}")
  File.open(@log_path, "w:utf-8") { |file| file.puts("ETL 脚本不存在:\n#{@script_path}") }
  exit(1)
end

def action_check_script
  strict_keywords = [
    '^# 开发人员:',
    '^# 更新日期:',
    '^# 业务模块:',
    '^# 定时任务:',
    '^# 代码步骤:',
    '^# 更新日期:',
    '^# 客户名称:',
    '^# 对接团队:',
    '^# 代码步骤:',
    '^# 业务描述:',
    '^set -e'
  ]
  script_content = File.read(@script_path)
  logger("脚本路径: #{@script_path}")
  logger("检测必填项:")
  strict_keywords.each do |keyword|
    if keyword == '^set -e'
      unset_set_e = script_content.scan(/#{keyword}/).flatten.size.zero?
      if unset_set_e
        logger("ERROR, 未配置 `set -e`，中止后续操作")
        exit(1)
      else
        logger("配置正常 - `set -e`")
      end
    else
      scaned_descriptions = script_content.scan(Regexp.new("#{keyword}\s?(.*?)$")).flatten
      if scaned_descriptions.size.zero?
        logger("ERROR, 未配置 `#{keyword}`，中止后续操作")
        exit(1)
      else
        @script_subject = scaned_descriptions[0].to_s if keyword.include?("业务模块")
        logger("配置正常 - #{keyword} #{scaned_descriptions[0]}")
      end
    end
  end
end

def action_execute_script
  `echo >> #{@log_path} 2>&1`
  `echo "$ bash #{@script_path} >> #{@log_path} 2>&1" >> #{@log_path} 2>&1`
  `echo >> #{@log_path} 2>&1`
  `echo "开始, 脚本执行" >> #{@log_path} 2>&1`
  `bash #{@script_path} >> #{@log_path} 2>&1`
  `echo "结束, 脚本执行" >> #{@log_path} 2>&1`
  `echo >> #{@log_path} 2>&1`
  logger "日志路径: #{@log_path}"
end

def action_sendmail_script
  cached_config = "/data/work/logs/sendmail.#{Time.now.strftime('%y%m%d%H%M%S')}.json"
  logger "邮件配置: #{cached_config}"

  config = JSON.parse(File.read(@sendmail_config))
  config['subject'] = @script_subject.to_s.strip
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
#{File.read(@log_path)}
</pre>
EOF

  File.open(cached_config, 'w:utf-8') { |file| file.puts(config.to_json) }
  logger `sypctl sendmail --file #{cached_config}`
end

action_check_script

exit unless options[:execute]
action_execute_script
action_sendmail_script
