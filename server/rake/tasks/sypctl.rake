# encoding: utf-8
require 'yaml'
require 'json'

namespace :sypctl do
  def encode(data)
    data.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end

  def logger(text, config = {})
    File.open("logs/#{config['description'] || 'ssh'}.log", "a:utf-8") do |file|
      file.puts(text.to_s.force_encoding('UTF-8'))
    end
  end

  def execute!(ssh, command, config = {})
    logger("\n\n--------------------\ntimestamp: #{Time.now.strftime('%y-%m-%d %H:%M:%S')}\ncommand: #{command}\n--------------------\n\n", config)

    ssh.exec!(command) do |_, stream, data|
      logger(data, config)
    end
  end

  desc "deploy sypctl env"
  task deploy: :environment do
    server_list = YAML.load(IO.read('config/server.yaml'))
    server_list.keys.map do |node|
      config = server_list[node]
      Thread.new(config) do |config|
        puts config["outer_ip"] + " doing..."
        Net::SSH.start(config["outer_ip"], config["username"], port: config["outer_port"], password: config["password"]) do |ssh|
          command = "curl -S http://gitlab.ibi.ren/syp/syp-saas-scripts/raw/dev-0.0.1/env.sh | bash"
          command = "bash /opt/scripts/syp-saas-scripts/sypctl.sh deployed"
          execute!(ssh, command, config)
          puts config["outer_ip"] + " done"
        end
      end
    end.each(&:join)
  end
end