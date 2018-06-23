# encoding: utf-8
app_path = File.expand_path('../..', __FILE__)

socket_file = "#{app_path}/tmp/unicorn.sock"
pid_file = "#{app_path}/tmp/pids/unicorn.pid"
old_pid = "#{pid_file}.oldbin"

# Nuke workers after 30 seconds instead of 60 seconds (the default)
timeout(30)

filepath = "#{app_path}/app-worker-processes"
processes_count = File.read(filepath).strip.to_i rescue 1
processes_count = processes_count > 0 ? processes_count : 1
worker_processes(processes_count) # increase or decrease

# Listen on fs socket for better performance
listen(socket_file, backlog: 1024)

pid(pid_file)

stderr_path("#{app_path}/logs/unicorn.log")
stdout_path("#{app_path}/logs/unicorn.log")

# To save some memory and improve performance
preload_app true

# 如果为 REE，则添加 copy_on_wirte_friendly
# http://www.rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
GC.respond_to?(:copy_on_write_friendly=) && GC.copy_on_write_friendly = true

# Force the bundler gemfile environment variable to
# reference the Сapistrano "current" symlink
before_exec do |_|
  ENV['BUNDLE_GEMFILE'] = File.expand_path('../Gemfile', File.dirname(__FILE__))
end

before_fork do |server, _|
  if File.exist?(old_pid) && server.pid != old_pid
    begin
      Process.kill('QUIT', File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      puts %(Send 'QUIT' signal to unicorn error!)
      # someone else did our job for us
    end
  end
end

after_fork do |server, worker|
  GC.disable
end
