# encoding:utf-8
require 'json'
require 'fileutils'
require 'digest/md5'
require 'lib/utils/device.rb'

def httparty_post_headers
  @headers ||= {'Content-Type' => 'application/json', 'User-Agent' => "sypctl #{ENV['SYPCTL_VERSION']};#{ENV['RUBY_VERSION']}"}
end

def agent_root_join(path)
  File.join(ENV["RAKE_ROOT_PATH"], path)
end
#
# agent instance methods
#
def agent_json_path; agent_root_join("db/agent.json"); end
def record_list_path; agent_root_join("db/records-#{Time.now.strftime('%y%m%d')}.list"); end

def password
  password_tmp_path = agent_root_join("password")
  unless File.exists?(password_tmp_path)
    File.open(password_tmp_path, "w:utf-8") { |file| file.puts((0..9).to_a.sample(6).join) }
  end
  File.read(password_tmp_path).strip
end

def print_agent_regisitered_info(print_or_not = true)
  puts agent_json_path if print_or_not
  if File.exists?(agent_json_path)
    data_hash = JSON.parse(File.read(agent_json_path))
    puts JSON.pretty_generate(data_hash) if print_or_not
  else
    data_hash = {}
    puts "该主机未注册，请执行命令 \`sypctl agent:task guard\`" if print_or_not
  end
  data_hash
end

def print_agent_will_regisiter_info(print_or_not = true)
  puts 
  puts "该主机 UUID: " + Utils::Device.uuid(false)

  if File.exists?(agent_json_path)
    data_hash = JSON.parse(File.read(agent_json_path))
    puts "已注册 UUID: " + data_hash['uuid']
  else
    data_hash = {}
    puts "该主机未注册，请执行命令 \`sypctl agent:task guard\`"
  end
end

def print_agent_log
  puts record_list_path
  if File.exists?(record_list_path)
    IO.readlines(record_list_path).each do |line|
      puts JSON.pretty_generate(JSON.parse(line))
    end
  else
    puts "无日志"
  end
end

def agent_device_init_info(use_cache = true)
  {
    uuid: Utils::Device.uuid(use_cache),
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
    version: ENV['SYPCTL_VERSION'],
    memory_usage: Utils::Device.memory_usage,
    memory_usage_description: Utils::Device.memory_usage_description.to_json,
    cpu_usage: Utils::Device.cpu_usage,
    cpu_usage_description: Utils::Device.cpu_usage_description.to_json,
    disk_usage: Utils::Device.disk_usage,
    disk_usage_description: Utils::Device.disk_usage_description.to_json
  }
end

def post_to_server_register
  url = "#{ENV['SYPCTL_API']}/api/v1/register"
  params = {device: agent_device_init_info(false)}
   
  init_uuid_path = agent_root_join("init-uuid")
  if File.exists?(init_uuid_path)
    init_uuid = File.read(init_uuid_path).strip
    params[:uuid] = init_uuid if init_uuid.length >= 10
  end
  human_name_path = agent_root_join("human-name")
  params[:device][:human_name] = File.read(human_name_path).strip if File.exists?(human_name_path)
  
  response = HTTParty.post(url, body: params.to_json, headers:httparty_post_headers)

  puts "POST #{url}\n\nparameters:"
  puts JSON.pretty_generate(params)
  puts "\nresponse:"
  puts response.code
  puts response.body

  if response.code == 201
    hsh = JSON.parse(response.body)
    hsh[:synced] = true
    File.open(agent_json_path, "w:utf-8") { |file| file.puts(hsh.to_json) }
    FileUtils.rm_f(init_uuid_path) if File.exists?(init_uuid_path)
    FileUtils.rm_f(human_name_path) if File.exists?(human_name_path)
  end
end

def post_to_server_job(options)
  url = "#{ENV['SYPCTL_API']}/api/v1/job"
  params = {job: options}
  response = HTTParty.post(url, body: params.to_json, headers: httparty_post_headers)

  puts "POST #{url}\n\nparameters:"
  puts JSON.pretty_generate(params)
  puts "\nresponse:"
  puts response.code
  puts response.body
end

def file_backup_db_hash
  backup_path = agent_root_join('file-backups')
  FileUtils.mkdir_p(backup_path) unless File.exists?(backup_path)
  db_hash_path = File.join(backup_path, 'db.hash')
  db_json_path = File.join(backup_path, 'db.json')
  db_hash = Digest::MD5.hexdigest(JSON.parse(File.read(db_json_path)).to_json)
  File.open(db_hash_path, 'w:utf-8') { |file| file.puts(db_hash) }
  db_hash
rescue => e
  e.message
end

def post_to_server_submitor
  url = "#{ENV['SYPCTL_API']}/api/v1/receiver"
  params = {device: agent_device_state_info, file_backup_db_hash: file_backup_db_hash}
  response = HTTParty.post(url, body: params.to_json, headers: httparty_post_headers)
  
  puts "POST #{url}\n\nparameters:"
  puts JSON.pretty_generate(params)
  puts "\nresponse:"
  puts response.code
  puts response.body

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

        `command -v dos2unix > /dev/null 2>&1 || sudo yum install -y dos2unix`
        hsh["jobs"].each do |job_hsh|
          job_path = agent_root_join("jobs/#{job_hsh['uuid']}")
          FileUtils.mkdir_p(job_path) unless File.exists?(job_path)
          job_json_path = File.join(job_path, 'job.json')
          job_command_path = File.join(job_path, 'job.sh')
          job_todo_path = agent_root_join("jobs/#{job_hsh['uuid']}.todo")
          File.open(job_json_path, "w:utf-8") { |f| f.puts(job_hsh.to_json) }
          File.open(job_todo_path, "w:utf-8") { |f| f.puts(job_hsh['uuid']) }

          brackets = job_hsh['command'].scan(/(".*?")/) || []
          brackets.flatten.each do |bracket|
            job_hsh['command'].sub!(bracket, bracket.gsub(/\s|"|\\"/, ''))
          end

          File.open(job_command_path, "w:utf-8") { |f| f.puts(job_hsh['command']) }

          `dos2unix #{job_command_path}`
        end
      end
      unless hsh["file_backups"].empty?
        backup_path = agent_root_join('file-backups')
        FileUtils.mkdir_p(backup_path) unless File.exists?(backup_path)
        db_json_path = File.join(backup_path, 'db.json')
        File.open(db_json_path, 'w:utf-8') { |file| file.puts(hsh["file_backups"].to_json) }
      end
      file.puts(agent_hsh.to_json)
    end
  end
end

def post_service_to_server_submitor
  url = "#{ENV['SYPCTL_API']}/api/v1/service"
  service_path = "/etc/sypctl/services.json"
  status_data_path = "/etc/sypctl/services.output"

  monitor_content, total_count, stopped_count = "file not exists", -1, -1
  if File.exists?(status_data_path)
    monitor_content = File.read(status_data_path)
    staus_data = JSON.parse(monitor_content)["data"]
    total_count = staus_data.count
    stopped_count = staus_data.select { |arr| arr.last.include?("未运行") }.count
  end

  uuid = agent_device_state_info[:uuid]
  params = {
    uuid: uuid,
    service: {
      uuid: uuid,
      hostname: `hostname`.strip,
      config: File.exists?(service_path) ? File.read(service_path) : "file not exists",
      monitor: monitor_content,
      total_count: total_count,
      stopped_count: stopped_count
    }
  }

  response = HTTParty.post(url, body: params.to_json, headers: httparty_post_headers)
  
  puts "POST #{url}\n\nparameters:"
  puts JSON.pretty_generate(params)
  puts "\nresponse:"
  puts response.code
  puts response.body
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