# encoding:utf-8
require 'lib/utils/device.rb'

def agent_root_join(path)
  File.join(ENV["RAKE_ROOT_PATH"], path)
end
#
# agent instance methods
#
def agent_json_path; agent_root_join("db/agent.json"); end
def record_list_path; agent_root_join("db/records-#{Time.now.strftime('%y%m%d')}.list"); end

def password
  password_tmp_path = agent_root_join(".password")
  unless File.exists?(password_tmp_path)
    File.open(password_tmp_path, "w:utf-8") { |file| file.puts((0..9).to_a.sample(6).join) }
  end
  File.read(password_tmp_path).strip
end

def agent_device_init_info
  @device ||= {
    uuid: Utils::Device.uuid,
    hostname: Utils::Device.hostname,
    username: 'sypagent',
    password: password,
    os_type: Utils::Device.os_type,
    os_version: Utils::Device.os_version,
    lan_ip: Utils::Device.lan_ip,
    wan_ip: Utils::Device.wan_ip,
    memory: Utils::Device.memory,
    memory_description: Utils::Device.memory_usage_description.to_json,
    cpu: Utils::Device.cpu,
    cpu_description: Utils::Device.cpu_usage_description.to_json,
    disk: Utils::Device.disk,
    disk_description: Utils::Device.disk_usage_description.to_json
  }
end

def agent_device_state_info
  agent_hsh = JSON.parse(File.read(agent_json_path))
  {
    uuid: agent_hsh['uuid'],
    whoami: Utils::Device.whoami,
    api_token: agent_hsh['api_token'],
    version: ENV['SYPCTL-VERSION'],
    memory_usage: Utils::Device.memory_usage,
    memory_usage_description: Utils::Device.memory_usage_description.to_json,
    cpu_usage: Utils::Device.cpu_usage,
    cpu_usage_description: Utils::Device.cpu_usage_description.to_json,
    disk_usage: Utils::Device.disk_usage,
    disk_usage_description: Utils::Device.disk_usage_description.to_json
  }
end

def post_to_server_register
  url = "#{ENV['SYPCTL-API']}/api/v1/register"
  params = {device: agent_device_init_info}.to_json
  response = HTTParty.post(url, body: params, headers: {'Content-Type' => 'application/json'})
  if response.code == 201
    hsh = JSON.parse(response.body)
    if hsh['api_token'] && hsh['api_token'].length == 32
      File.open(agent_json_path, "w:utf-8") do |file| 
        agent_hsh = agent_device_init_info
        agent_hsh[:api_token] = hsh['api_token']
        agent_hsh[:synced] = true
        file.puts(agent_hsh.to_json)
      end
    end
  end
end

def post_to_server_job(options)
  url = "#{ENV['SYPCTL-API']}/api/v1/job"
  params = {job: options}.to_json
  response = HTTParty.post(url, body: params, headers: {'Content-Type' => 'application/json'})
end

def post_to_server_submitor
  url = "#{ENV['SYPCTL-API']}/api/v1/receiver"
  params = {device: agent_device_state_info}.to_json
  response = HTTParty.post(url, body: params, headers: {'Content-Type' => 'application/json'})
  if response.code == 201
    hsh = JSON.parse(response.body)
    File.open(record_list_path, "a+:utf-8") do |file|
      agent_hsh = agent_device_state_info
      agent_hsh[:server_record_id] = hsh["id"]
      unless hsh["jobs"].empty?
        # 执行部署脚本前，先置任务状态为进行中，
        # 否则部署脚本中有提交操作时，会再次获取到部署任务
        hsh["jobs"].each do |job_hsh|
          job_hsh['state'] = 'dealing'
          post_to_server_job(job_hsh)
        end

        agent_hsh["jobs"] = hsh["jobs"].map do |job_hsh|
          `echo "#{job_hsh['command']}" > ~/.sypctl-command`
          `rm -f ~/.sypctl-command-output`
          `bash ~/.sypctl-command > ~/.sypctl-command-output 2>&1`

          job_hsh['state'] = 'done'
          job_hsh['output'] =  `test -f ~/.sypctl-command-output && cat ~/.sypctl-command-output || echo '无输出'`
          post_to_server_job(job_hsh)

          job_hsh
        end
      end
      file.puts(agent_hsh.to_json)
    end
  end
end

#
# syoctl instance methods
#
def encode(data)
  data.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
end

def logger(text, config = {})
  File.open("logs/#{config['description'] || 'ssh'}-#{Time.now.strftime('%y%m%d')}.log", "a+:utf-8") do |file|
    file.puts(text.to_s.force_encoding('UTF-8'))
  end
end

def execute!(ssh, commands, config = {})
  commands = commands.is_a?(Array) ? commands : [commands]
  commands.each do |command|
    logger("\n\n#{'>'*30}\ntimestamp: #{Time.now.strftime('%y-%m-%d %H:%M:%S')}\n\n```\n#{command}\n```\n#{'<'*30}\n\n", config)
    ssh.exec!(command) { |_, stream, data| logger(data, config) }
  end
end

def add_id_rsa_pub_to_authorized_keys(ssh, config)
  IO.readlines("config/id_rsa_pub.list").uniq.each do |id_rsa_pub|
    id_rsa_pub = id_rsa_pub.strip
    next if id_rsa_pub.empty?
    
    command = <<-EOF.strip_heredoc
        grep "#{id_rsa_pub}" ~/.ssh/authorized_keys > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "alread exists: #{id_rsa_pub}"
        else
            echo "echo '#{id_rsa_pub}' >> ~/.ssh/authorized_keys"
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