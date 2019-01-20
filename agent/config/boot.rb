# encoding: utf-8
require 'rubygems'

root_path = File.dirname(File.dirname(__FILE__))
ENV['APP_ROOT_PATH'] = root_path
ENV['RACK_ENV']    ||= 'development'
ENV['VIEW_PATH']     = %(#{root_path}/server)
unicorn_port_path    = File.join(root_path, 'app-port')
ENV['UNICORN_PORT']  = File.exist?(unicorn_port_path) ? File.read(unicorn_port_path).strip : '8086'
ENV["SYPCTL-VERSION"] = File.read("../version") rescue "unknown"

begin
  ENV['BUNDLE_GEMFILE'] ||= %(#{root_path}/Gemfile)
  require 'rake'
  require 'bundler'
  Bundler.setup
rescue => e
  puts e.backtrace
  exit
end
Bundler.require(:default, ENV['RACK_ENV'])

$LOAD_PATH.unshift(root_path)
$LOAD_PATH.unshift(%(#{root_path}/server))

sypctl_home = File.join(root_path, "../sypctl.sh")
ENV['PLATFORM_OS']        = `bash #{sypctl_home} variable os_platform`.strip.downcase rescue `uname -s`
ENV['EXECUTE_PATH']       = `echo ${SYPCTL_EXECUTE_PATH}`.strip
ENV['APP_RUNNER']         = `whoami`.strip.downcase
ENV['HOSTNAME']           = `hostname`.strip.downcase
ENV['WEB_TITLE']          = File.read("#{root_path}/web-title").strip rescue "生意+ 代理"
ENV['WEB_FAVICON']        = File.read("#{root_path}/web-favicon").strip rescue "http://p93zhu9fx.bkt.clouddn.com/favicon-syp.png"
ENV['STARTUP']            = Time.now.to_s
ENV['UNICORN_PID_PATH'] ||= %(#{root_path}/tmp/pids/unicorn.pid)

require 'lib/core_ext/string.rb'
require 'config/asset_handler'
require 'application_controller.rb'
require 'cpanel_controller.rb'
