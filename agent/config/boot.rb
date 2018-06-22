# encoding: utf-8
require 'rubygems'

root_path = File.dirname(File.dirname(__FILE__))
ENV['APP_ROOT_PATH'] = root_path
ENV['RACK_ENV']    ||= 'development'
ENV['VIEW_PATH']     = %(#{root_path}/server)
unicorn_port_path    = File.join(root_path, 'app-port')
ENV['UNICORN_PORT']  = File.exist?(unicorn_port_path) ? File.read(unicorn_port_path).strip : '8086'

begin
  ENV['BUNDLE_GEMFILE'] ||= %(#{root_path}/Gemfile)
  puts ENV['BUNDLE_GEMFILE']
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

ENV['PLATFORM_OS']        = `uname -s`.strip.downcase
ENV['APP_RUNNER']         = `whoami`.strip.downcase
ENV['HOSTNAME']           = `hostname`.strip.downcase
ENV['STARTUP']            = Time.now.to_s
ENV['UNICORN_PID_PATH'] ||= %(#{root_path}/tmp/pids/unicorn.pid)

require 'lib/core_ext/string.rb'
require 'config/asset_handler'
require 'application_controller.rb'
