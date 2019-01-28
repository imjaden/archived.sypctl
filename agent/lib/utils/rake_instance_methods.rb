# encoding:utf-8
require 'json'
require 'fileutils'
require 'digest/md5'
require 'lib/utils/http.rb'
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
  password_tmp_path = agent_root_join(".config/password")
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
  puts "该主机 UUID: " + Sypctl::Device.uuid(false)

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
    uuid: Sypctl::Device.uuid(use_cache),
    hostname: Sypctl::Device.hostname,
    username: 'sypagent',
    password: password,
    os_type: Sypctl::Device.os_type,
    os_version: Sypctl::Device.os_version,
    lan_ip: Sypctl::Device.lan_ip,
    wan_ip: Sypctl::Device.wan_ip,
    memory: Sypctl::Device.memory,
    memory_description: Sypctl::Device.memory_usage_description.to_json,
    cpu: Sypctl::Device.cpu,
    cpu_description: Sypctl::Device.cpu_usage_description.to_json,
    disk: Sypctl::Device.disk,
    disk_description: Sypctl::Device.disk_usage_description.to_json
  }
end

def agent_device_state_info
  agent_hash = JSON.parse(File.read(agent_json_path))
  {
    uuid: agent_hash['uuid'],
    whoami: Sypctl::Device.whoami,
    api_token: agent_hash['api_token'],
    version: ENV['SYPCTL_VERSION'],
    memory_usage: Sypctl::Device.memory_usage,
    memory_usage_description: Sypctl::Device.memory_usage_description.to_json,
    cpu_usage: Sypctl::Device.cpu_usage,
    cpu_usage_description: Sypctl::Device.cpu_usage_description.to_json,
    disk_usage: Sypctl::Device.disk_usage,
    disk_usage_description: Sypctl::Device.disk_usage_description.to_json
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
  
  response = Sypctl::Http.post(url, params)

  if response['code'] == 201
    response['hash']['synced'] = true
    File.open(agent_json_path, "w:utf-8") { |file| file.puts(response['hash'].to_json) }
    FileUtils.rm_f(init_uuid_path) if File.exists?(init_uuid_path)
    FileUtils.rm_f(human_name_path) if File.exists?(human_name_path)
  end
end

def post_to_server_job(options)
  url = "#{ENV['SYPCTL_API']}/api/v1/job"
  params = {job: options}
  response = Sypctl::Http.post(url, params)
end

def file_backup_db_hash
  backup_path = agent_root_join('db/file-backups')
  FileUtils.mkdir_p(backup_path) unless File.exists?(backup_path)
  db_hash_path = File.join(backup_path, 'db.hash')
  db_json_path = File.join(backup_path, 'db.json')
  return 'FileNotExist' unless File.exists?(db_json_path)

  db_hash = Digest::MD5.hexdigest(JSON.parse(File.read(db_json_path)).to_json)
  File.open(db_hash_path, 'w:utf-8') { |file| file.puts(db_hash) }
  db_hash
rescue => e
  e.message
end

def post_to_server_submitor
  url = "#{ENV['SYPCTL_API']}/api/v1/receiver"
  params = {device: agent_device_state_info, file_backup_db_hash: file_backup_db_hash}
  response = Sypctl::Http.post(url, params)

  if response['code'] == 201
    File.open(record_list_path, "a+:utf-8") do |file|
      agent_hash = agent_device_state_info
      agent_hash[:server_record_id] = response['hash']['id']
      unless response['hash']['jobs'].empty?
        # 执行部署脚本前，先置任务状态为进行中，
        # 否则部署脚本中有提交操作时，会再次获取到部署任务
        response['hash']['jobs'].each do |job_hash|
          job_hash['state'] = 'dealing'
          post_to_server_job(job_hash)
        end

        `command -v dos2unix > /dev/null 2>&1 || sudo yum install -y dos2unix`
        response['hash']['jobs'].each do |job_hash|
          job_path = agent_root_join("db/jobs/#{job_hash['uuid']}")
          FileUtils.mkdir_p(job_path) unless File.exists?(job_path)
          job_json_path = File.join(job_path, 'job.json')
          job_command_path = File.join(job_path, 'job.sh')
          job_todo_path = agent_root_join("db/jobs/#{job_hash['uuid']}.todo")
          File.open(job_json_path, "w:utf-8") { |f| f.puts(job_hash.to_json) }
          File.open(job_todo_path, "w:utf-8") { |f| f.puts(job_hash['uuid']) }

          brackets = job_hash['command'].scan(/(".*?")/) || []
          brackets.flatten.each do |bracket|
            job_hash['command'].sub!(bracket, bracket.gsub(/\s|"|\\"/, ''))
          end

          File.open(job_command_path, "w:utf-8") { |f| f.puts(job_hash['command']) }

          `dos2unix #{job_command_path}`
        end
      end

      unless response['hash']['file_backups'].empty?
        backup_path = agent_root_join('db/file-backups')
        FileUtils.mkdir_p(backup_path) unless File.exists?(backup_path)
        db_hash_path = File.join(backup_path, 'db.hash')
        db_json_path = File.join(backup_path, 'db.json')
        db_hash = Digest::MD5.hexdigest(response['hash']['file_backups'].to_json)
        File.open(db_hash_path, 'w:utf-8') { |file| file.puts(db_hash) }
        File.open(db_json_path, 'w:utf-8') { |file| file.puts(response['hash']['file_backups'].to_json) }
      end
      file.puts(agent_hash.to_json)
    end
  end
end

# #service# 
# 提交监控服务配置档至服务器
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
      config: File.exists?(service_path) ? File.read(service_path) : "FileNotExist",
      monitor: monitor_content,
      total_count: total_count,
      stopped_count: stopped_count
    }
  }

  Sypctl::Http.post(url, params)
end

# 更新代理端本机信息
def refresh_agent_system_meta
  options = {
    uuid: Sypctl::Device.uuid(true),
    hostname: Sypctl::Device.hostname,
    os_type: Sypctl::Device.os_type,
    os_version: Sypctl::Device.os_version,
    lan_ip: Sypctl::Device.lan_ip,
    wan_ip: Sypctl::Device.wan_ip,
    memory: Sypctl::Device.memory,
    memory_description: Sypctl::Device.memory_usage_description,
    cpu: Sypctl::Device.cpu,
    cpu_description: Sypctl::Device.cpu_usage_description,
    disk: Sypctl::Device.disk,
    disk_description: Sypctl::Device.disk_usage_description,
    whoami: Sypctl::Device.whoami,
    version: ENV['SYPCTL_VERSION']
  }
  File.open(agent_root_join('db/system.json'), 'w:utf-8') { |file| file.puts(options.to_json) }

  config = {
    headings: ['键名', '键值'],
    width: ['20%', '80%'],
    rows: [
      ['UUID', options[:uuid]],
      ['主机名', options[:hostname]],
      ['内网IP', options[:lan_ip]],
      ['系统', [options[:os_version], options[:os_version]].join(' ')],
      ['内存', options[:memory]],
      ['磁盘', options[:disk]],
      ['运行账号', options[:whoami]],
      ['代理版本', options[:version]]
    ]
  }
  File.open(agent_root_join('monitor/index/系统运行状态.json'), 'w:utf-8') { |file| file.puts(config.to_json) }
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