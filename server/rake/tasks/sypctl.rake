# encoding: utf-8
require 'yaml'
require 'json'

namespace :sypctl do
  def encode(data)
    data.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end

  def logger(text, config = {})
    File.open("logs/#{Time.now.strftime('%y%m%d')}-#{config['description'] || 'ssh'}.log", "a:utf-8") do |file|
      file.puts(text.to_s.force_encoding('UTF-8'))
    end
  end

  def execute!(ssh, command, config = {})
    logger("\n\n#{'>'*30}\ntimestamp: #{Time.now.strftime('%y-%m-%d %H:%M:%S')}\ncommand: #{command}\n#{'<'*30}\n\n", config)

    ssh.exec!(command) do |_, stream, data|
      logger(data, config)
    end
  end

  def add_id_rsa_pub_to_authorized_keys(ssh, config)
    [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4CtZOMtRxqubVf2dyyZKhN+Kjyrp8bSCz0I7ZMRTpUuhGvAjIm5NEmP41CAWr3/PE1tujlfAksfnSmsIXMoKEu8pqkwRScVT0Sz0bHlXbWdAzW2vH7RlnMQ6RaZQYqZ0d5RoFePWX6Kv8y78zIbWc3tNfFDznFxddKOAnGtxFM4YNXbJgUqIyXe26djdYnBQFub2V5J39h5dyaWV8JZjgIBc7+fp72+jScMSRBLwCoG524LLTJgQ+dKt/qLxbnv3mPagvIQLUOnep4aXg0ZzbyuhGAraGkuEkrzqpp/yuLuhXgK/ppGZQtK1BSYMR2XbE2myKXAG2AF7tn+GNXNZR root@hadoop1.localdomain",
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDbWqUbzFXmDGjEDSZsMiCTILL3Yk94s4rmn1Qssmq4R4R5jwbEUMls2ntMIQ0VoQdW0/OyJ1aBxXloICM1XYYHb+Uwgp1Raz+HOe2Kg8IvMP9+6Mgtdo13Ou/m34cKZlcax3tvi1uXyLuW+V8Gl2L7ksUMfHBlbYUt5S1wt7ZIbVuFiGhxy5nrzmxsLT25MO7bhXtcTHwgjin2EVC14eQaUr4XjE2s7zY+nT+XmcYRC0vmrWcIq6zVxgUstc9ZtoyIN9/MfX1JwU3bK6ggLQGw9BB3kyUhQSy9MUc6oPY/eOZEeflDw8mfJn3ENLqOhoV9JFqGMkpGiFkYwKpM3IAN root@hadoop2.localdomain",
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDekDaTJ0XWp9hADgTpEMKE3ZHdb4K1JAh6rvcNuUih3yrcGCZBHg0ZGuEhlUr6x288DtedvEcwIKc2GgHqsCF4B0VbXwWY541RkuKES7aB6p04Itw3Uu5SpQ6TQPZ2LU2OqF+Xg6nj42WGolVUZWKOpnHazD0HPcZUxDHbxYccXVVaNGel8xZstLYdtgnV9BGLytzC0nP6wJgJcwVwYpLDTU8uW3HexotJppb6VNhkwq1Kf0oEt97AM0/W5HIHXZuIjBgQUz1ZgKItTiefKWiaNMc8or5IehIdtdyOjOKX6t3tnB+Fc5LR4MB6CpQcpsFPgKqGqTAZ2SI08oAbTGPh root@hadoop3.localdomain",
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDZQHZiZAIQQxpMWJlyoh0LwVLb3nlIgYY2GIaAYOQ0K7dSv8doVWvqvbIFAFMFpJDyXM9IpDWkTQ5gd8GWkdNzgadbjthBsgeAWfwsggL/Gkaprryku6BAWsbmy4ThboDHF96x2RaQSSPmlZzmpaBLDkesevWsrAlwI5l6c+SFso1DPys6yBj4iF5e4a2YOEPaM2+IJsKG0B/NnATOvjdYQpeSRxLht/B2xFgOOq4eVHu/s7+nk5QTOW/Qn69rWWrroN4tmT4DgiwqZDUI2KoIPqky1wffMLsHa2nYWQyfNePnMqfWlTDKwgpHPR+Dt0LXLbTAc3Zvh09we+FlRfdV root@hadoop4.localdomain",
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDmxORdsbUhSu+CYh6VJoMi/79H69j5gsN7+FCmmqpYxT4BoXgPYk5mhaKu/QYApQJgvUHBl6aonKHEYAZ967eEzQKSfDSyoSjjECxNOBDPswFZuE+u39KL6sVIF7KVZb5RAo00rMkNnhqT/h49AaxUw/ko49nXjlHaW+IRIL+njsmw9erVIFk6IN0VlEzluixGfNP5s5bYPjffi7SpKTUMkkvy5pCea9AYp/qSIQTV7TRY81h4bKT8Ac1grvmpHyjJsBzBVFDgRrS6DTDSiaey7mqbz8qWQABTCIqvN2u2wlhVF/vQuFFNaYbKKxHoULF4GeU+ZdPzd1/sVRLCRKyB root@hadoop5.localdomain",
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDIkjeUN+a8ATm/nNI5Urd/dVYeBzHQRpWpxbyP1gfmfA5oKz/B7+jjOsl8rP8S2ubsWNXOKmUV663VAwrBLoyekyGH7ByLjTTVUUzENwXZRxAfVSQ4YcsuvttUoWLUAJVoMgGzN1xrBzFuBSEin3KOVJJZNNVfd/rI3UuZufx2tZ9rLPsGfXfuumKPWg0uN9vl4YoksBT+6vsHEiiM8cw2s1a2CJwUp5MvIb73krI21bh/FoZ+6NhdZhyodHZeqn9la9ACWcJvGhUuLFaajLALR2RQ9SRliVopeR3rdSVAw9kSCZSeFSv6MXWmS28CU4LEQmg170GsxUz7x1EsFLB28tcoV+sySAMpuXpJnloeHkZ/LnQiYRUo0Z8z+I/ok2VnoWaB7Ah9NgIpohbIS/FctHQ9wZOYup1I6EgUFBLg4NuFWflc2V64N0lGkbGJpEOGxExUF7Cc188RSlIzwWf1KeKNrpDgmCLKaPE43Cuxefb2y2TQqgqAxMnVvaw6xlUDqH4lDhfITmbuzI6jaONrOoCEGbtZCO/pkluMD5+QKGL0sIjBEuh9mG8vtm7HVtEThhy1LXj0T1wLzTRy/YNqYfbBhWPmKNRgdhb0S5Jc/UUKpbTlXbyEd1tZc160cawCMGTHR/Ed92k/WS02VTV4IWY0IiB98Tol1xQUr9mS/w== jay_li@intfocus.com"
    ].each do |id_rsa_pub|
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

  desc "deploy sypctl env"
  task deploy: :environment do
    server_list = YAML.load(IO.read('config/server.yaml'))
    server_list.keys.map do |node|
      config = server_list[node]
      Thread.new(config) do |config|
        puts "#{Time.now.strftime('%y-%m-%d %H:%M:%S')} - #{config['outer_ip']}:#{config['outer_port']} doing..."
        begin
          Net::SSH.start(config["outer_ip"], config["username"], port: config["outer_port"], password: config["password"]) do |ssh|
            # add_id_rsa_pub_to_authorized_keys(ssh, config)
            command = "curl -S http://gitlab.ibi.ren/syp/syp-saas-scripts/raw/dev-0.0.1/env.sh | bash"

            puts "#{Time.now.strftime('%y-%m-%d %H:%M:%S')} - #{config['outer_ip']}:#{config['outer_port']} done"
          end
        rescue => e
          puts "#{Time.now.strftime('%y-%m-%d %H:%M:%S')} - #{config['outer_ip']}:#{config['outer_port']} abort for #{e.message}"
        end
      end
    end.each(&:join)
  end
end