# encoding: utf-8
require 'yaml'
require 'json'
require 'fileutils'

namespace :sypctl do
  task clean_empty_rows: :environment do
    unless File.exists?(ENV['filepath'].to_s)
      puts "Error: 要清理多余空行的文件路径"
      exit
    end

    filepath = ENV['filepath']
    content = File.read(filepath)
    while content.include?("\n\n\n")
      content.gsub!("\n\n\n", "\n\n")
    end

    if content != File.read(filepath)
      filepath_bak = "#{filepath}.#{Time.now.strftime('%y%m%d%H%M%S')}"
      `cp #{filepath} #{filepath_bak}`
      File.open(filepath, "w:utf-8") { |file| file.puts(content) }

      puts "已修改文档: #{filepath}"
      puts "备份文档路径: #{filepath_bak}"
    else
      puts "#{filepath} 文档中无多余空行"
    end
  end

  desc "deploy sypctl env"
  task deploy: :environment do
    task_list = IO.readlines('config/deploy_tasks.sh').map(&:strip).delete_if { |line| line.empty? or line.start_with?("#") }
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

            execute!(ssh, task_list, config)
            puts "#{Time.now.strftime('%y-%m-%d %H:%M:%S')} - #{device_id} done, duration #{(Time.now - start_time).round(3)}s"
          end
        rescue => e
          puts "#{Time.now.strftime('%y-%m-%d %H:%M:%S')} - #{device_id} abort for #{e.message}"
        end
      end
    end.each(&:join)
  end
end