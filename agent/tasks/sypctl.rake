# encoding: utf-8
require 'yaml'
require 'json'
require 'fileutils'

namespace :sypctl do
  def encode(data)
    data.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end

  def logger(text, config = {})
    File.open("logs/#{Time.now.strftime('%y%m%d')}-#{config['description'] || 'ssh'}.log", "a:utf-8") do |file|
      file.puts(text.to_s.force_encoding('UTF-8'))
    end
  end

  def execute!(ssh, commands, config = {})
    commands = commands.is_a?(Array) ? commands : [commands]
    commands.each do |command|
      logger("\n\n#{'>'*30}\ntimestamp: #{Time.now.strftime('%y-%m-%d %H:%M:%S')}\ncommand: #{command}\n#{'<'*30}\n\n", config)
      ssh.exec!(command) { |_, stream, data| logger(data, config) }
    end
  end

  def add_id_rsa_pub_to_authorized_keys(ssh, config)
    IO.readlines("config/id_rsa_pub.list").each do |id_rsa_pub|
      next if id_rsa_pub.strip.empty?
      
      command = <<-EOF.strip_heredoc
          grep "#{id_rsa_pub}" ~/.ssh/authorized_keys > /dev/null 2>&1
          if [[ $? -eq 0 ]]; then
              echo "alread exists: #{id_rsa_pub}"
          else
              echo "add to ~/.ssh/authorized_keys: #{id_rsa_pub}"
              echo '#{id_rsa_pub}' >> ~/.ssh/authorized_keys
          fi
      EOF
      execute!(ssh, command, config)
    end
  end

  def print_server_info(server_list)
    server_list.keys.each do |node|
      config = server_list[node]

      puts "## #{config['description']}(#{config['inner_ip']})"
      puts
      puts "- 内网/端口: #{config['inner_ip']}/#{config['inner_port']}"
      puts "- 外网/端口: #{config['outer_ip']}/#{config['outer_port']}"
      puts "- 账号: #{config['username']}"
      puts "- 密码: #{config['password']}"
      puts
    end
  end

  desc 'backup logs'
  task logs: :environment do
    FileUtils.mv("logs", "#{Time.now.strftime("%y%m%d%H%M%S")}-logs")
    FileUtils.mkdir("logs")
  end

  desc "deploy sypctl env"
  task deploy: :environment do
    server_list = YAML.load(IO.read('config/server.yaml'))
    server_list.keys.map do |node|
      config = server_list[node]
      Thread.new(config) do |config|
        device_id = "#{config['outer_ip']}:#{config['outer_port']}@#{config['description']}"
        start_time = Time.now
        puts "#{Time.now.strftime('%y-%m-%d %H:%M:%S')} - #{device_id} doing..."
        begin
          Net::SSH.start(config["outer_ip"], config["username"], port: config["outer_port"], password: config["password"]) do |ssh|
            # add_id_rsa_pub_to_authorized_keys(ssh, config)
            commands = [
              "curl -sS http://gitlab.ibi.ren/syp/sypctl/raw/dev-0.0.1/env.sh | bash"
            ]
            execute!(ssh, commands, config)
            puts "#{Time.now.strftime('%y-%m-%d %H:%M:%S')} - #{device_id} done, duration #{(Time.now - start_time).round(3)}s"
          end
        rescue => e
          puts "#{Time.now.strftime('%y-%m-%d %H:%M:%S')} - #{device_id} abort for #{e.message}"
        end
      end
    end.each(&:join)
  end
end