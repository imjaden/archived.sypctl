# encoding: utf-8
require 'yaml'
require 'json'
require 'fileutils'

namespace :sypctl do
  desc "deploy sypctl env"
  task deploy: :environment do
    task_list = IO.readlines('config/deploy_tasks.sh').map(&:strip).delete_if { |line| line.empty? or line.start_with?("#") }
    server_list = YAML.load(IO.read('config/server.yaml'))
    
    server_list.keys.map do |node|
      config = server_list[node]
      Thread.new(config) do |config|
        if config['description'].include?("hadoop")
          device_id = "#{config['outer_ip']}:#{config['outer_port']}@#{config['description']}"
          start_time = Time.now
          puts "#{Time.now.strftime('%y-%m-%d %H:%M:%S')} - #{device_id} doing..."
          begin
            Net::SSH.start(config["outer_ip"], config["username"], port: config["outer_port"], password: config["password"]) do |ssh|
              # add_id_rsa_pub_to_authorized_keys(ssh, config)

              execute!(ssh, task_list, config)
              puts "#{Time.now.strftime('%y-%m-%d %H:%M:%S')} - #{device_id} done, duration #{(Time.now - start_time).round(3)}s"
            end
          rescue => e
            puts "#{Time.now.strftime('%y-%m-%d %H:%M:%S')} - #{device_id} abort for #{e.message}"
          end
        end
      end
    end.each(&:join)
  end
end