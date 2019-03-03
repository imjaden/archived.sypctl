# encoding: utf-8
require 'json'
require 'fileutils'
require 'digest/md5'
require 'securerandom'

namespace :app do
  def _timestamp
    Time.now.strftime('%y-%m-%d %H:%M:%S')
  end

  def execute_job_logger(info, job_uuid = nil)
    message = "#{_timestamp} - #{info}"
    unless job_uuid
      puts message
      return false
    end

    output_path = File.join(ENV['RAKE_ROOT_PATH'], "db/jobs/#{job_uuid}/job.output")
    File.open(output_path, 'a+:utf-8') { |file| file.puts(message) }

    sandbox_path = File.join(ENV['RAKE_ROOT_PATH'], "db/jobs/#{job_uuid}")
    job_output_path = File.join(sandbox_path, 'job.output')
    job_output = File.exists?(job_output_path) ? IO.read(job_output_path) : "无输出"

    post_to_server_job({uuid: job_uuid, state: 'executing', output: job_output})
  rescue => e
    puts "#{__FILE__}@#{__LINE__}: #{e.message}"
  end

  def check_file_md5(label, path, md5, job_uuid)
    if File.exists?(path)
      local_md5 = Digest::MD5.file(path).hexdigest
      if md5 == local_md5
        execute_job_logger("#{label}检查: 文件哈希一致 #{md5}", job_uuid)
        return true
      else
        execute_job_logger("#{label}检查: 文件哈希不一致，期望 #{md5} 而实际是 #{local_md5}", job_uuid)
      end
    else
      execute_job_logger("#{label}异常: 文件不存在 #{path}", job_uuid)
    end
    return false
  end

  def get_api_info(label, url, job_uuid)
    response = Sypctl::Http.get(url)
    if response['code'] != 200
      execute_job_logger("查询异常: 获取#{label}信息失败 - #{response['hash']['message']}", job_uuid)
      execute_job_logger("- 请求链接: #{url}", job_uuid)
      execute_job_logger("- 查询描述: #{response['hash']['message']}", job_uuid)
      execute_job_logger("退出部署操作", job_uuid)
      return false
    end
    execute_job_logger("查询成功: 获取应用信息", job_uuid)
    response['hash']['data']
  end

  def download_version_file_deprecated(url, config, job_uuid)
    versions_path = File.join(ENV['RAKE_ROOT_PATH'], "db/versions")
    version_path = File.join(versions_path, config['version']['uuid'])
    version_file_path = File.join(version_path, config['version']['file_name'])

    if File.exists?(version_file_path)
      current_md5 = Digest::MD5.file(version_file_path).hexdigest
      if current_md5 == config['version']['md5']
        execute_job_logger("下载状态: 版本文件已下载，哈希值一致为 #{current_md5}", job_uuid)
        execute_job_logger("文件路径: #{version_file_path}", job_uuid)
        return version_file_path
      end
    end
    
    FileUtils.mkdir_p(version_path) unless File.exists?(version_path)
    File.open(File.join(version_path, 'config.json'), 'w:utf-8') { |file| file.puts(config.to_json) }

    execute_job_logger("下载链接: #{url}", job_uuid)
    btime = Time.now
    response = Sypctl::Http.download_version_file(url, version_file_path, job_uuid)

    execute_job_logger("下载状态: #{response.inspect}", job_uuid)
    execute_job_logger("文件路径: #{version_file_path}", job_uuid) if File.exists?(version_file_path)
    execute_job_logger("文件大小: #{File.exists?(version_file_path) ? File.size(version_file_path).number_to_human_size : 'NotFound'}", job_uuid)
    execute_job_logger("下载用时: #{Time.now - btime}s", job_uuid)
    return version_file_path
  end

  def download_version_file(url, config, job_uuid)
    versions_path = File.join(ENV['RAKE_ROOT_PATH'], "db/versions")
    version_folder = File.join(versions_path, config['version']['uuid'])
    version_file_path = File.join(version_folder, config['version']['file_name'])

    if File.exists?(version_file_path)
      current_md5 = Digest::MD5.file(version_file_path).hexdigest
      if current_md5 == config['version']['md5']
        execute_job_logger("下载状态: 版本文件已下载，哈希值一致为 #{current_md5}", job_uuid)
        execute_job_logger("文件路径: #{version_file_path}", job_uuid)
        return version_file_path
      end
    end
    
    FileUtils.mkdir_p(version_folder) unless File.exists?(version_folder)
    File.open(File.join(version_folder, 'config.json'), 'w:utf-8') { |file| file.puts(config.to_json) }

    bash_command = "bash lib/utils/version_downloader.sh #{url} #{config['version']['file_name']} db/versions/#{config['version']['uuid']}"
    execute_job_logger("下载链接: #{url}", job_uuid)
    execute_job_logger("执行下载: #{bash_command}", job_uuid)

    download_pid_path = "#{version_file_path}.pid"
    download_log_path = "#{version_file_path}.log"
    download_state = "running"
    begin_time = Time.now

    while download_state == "running"
      bash_message = `#{bash_command}`
      execute_job_logger("下载状态: #{bash_message}", job_uuid)
      # sleep 5

      if File.exists?(download_pid_path)
        download_pid = File.read(download_pid_path).strip
        expected_pid = `ps ax | awk '{print $1}' | grep -e "^#{download_pid}$"`.strip
        download_state = (download_pid == expected_pid ? "running" : "done")
      else
        download_state == "done"
      end
    end

    execute_job_logger("文件路径: #{version_file_path}", job_uuid) if File.exists?(version_file_path)
    execute_job_logger("文件大小: #{File.exists?(version_file_path) ? File.size(version_file_path).number_to_human_size : 'NotFound'}", job_uuid)
    execute_job_logger("下载用时: #{Time.now - begin_time}s", job_uuid)
    return version_file_path
  end

  def delete_file_if_exists(label, path, backup_path = nil, job_uuid)    
    return unless File.exists?(path)
    if backup_path && File.exists?(backup_path)
      backup_file_path = File.join(backup_path, Time.now.strftime('%y%m%d%H%M%S') + '-' + File.basename(path))
      FileUtils.mv(path, backup_file_path)
      execute_job_logger("#{label}预检: 移动文件 #{path} 至 #{backup_file_path}", job_uuid)
    else
      FileUtils.rm_rf(path)
      execute_job_logger("#{label}预检: 删除已存在文件 #{path}" , job_uuid)
    end
  end

  def deploy_app(sandbox_path, job_uuid)
    config_path = File.join(sandbox_path, 'config.json')
    config = JSON.parse(File.read(config_path)) rescue {}

    execute_job_logger("Bundle 进程 ID: #{Process.pid}", job_uuid)
    execute_job_logger('部署开始...', job_uuid)
    if !config['app.uuid'] || !config['version.uuid']
      execute_job_logger('配置异常: 应用/版本 UUID 未配置，退出操作', job_uuid)
      exit 1
    end

    data = get_api_info('应用', "#{ENV['SYPCTL_API']}/api/v1/app?uuid=#{config['app.uuid']}", job_uuid)
    exit 1 unless data

    config['app'] = data
    execute_job_logger("应用信息:", job_uuid)
    execute_job_logger("    - UUID: #{data['uuid']}", job_uuid)
    execute_job_logger("    - 应用名称: #{data['name']}", job_uuid)
    execute_job_logger("    - 文件类型: #{data['file_type']}", job_uuid)
    execute_job_logger("    - 文件名称: #{data['file_name']}", job_uuid)
    execute_job_logger("    - 部署目录: #{data['file_path']}", job_uuid)

    data = get_api_info('版本', "#{ENV['SYPCTL_API']}/api/v1/app/version?uuid=#{config['version.uuid']}", job_uuid)
    exit 1 unless data

    config['version'] = data
    execute_job_logger("版本信息:", job_uuid)
    execute_job_logger("    - UUID: #{data['uuid']}", job_uuid)
    execute_job_logger("    - 版本名称: #{data['version']}", job_uuid)
    execute_job_logger("    - 文件大小: #{data['file_size'].to_i.number_to_human_size}", job_uuid)
    execute_job_logger("    - 文件名称: #{data['file_name']}", job_uuid)
    execute_job_logger("    - 文件哈希: #{data['md5']}", job_uuid)
    execute_job_logger("    - 下载链接: #{data['download_path']}", job_uuid)
    
    File.open(config_path, 'w:utf-8') { |file| file.puts(config.to_json) }

    btime = Time.now
    url = "#{ENV['SYPCTL_API']}#{config['version']['download_path']}"
    
    local_version_path = download_version_file(url, config, job_uuid)
    version_file_state = check_file_md5('下载', local_version_path, config['version']['md5'], job_uuid)
    download_try_time = 2
    while !version_file_state && download_try_time <= 5
      execute_job_logger("第#{download_try_time}次尝试下载", job_uuid)
      local_version_path = download_version_file(url, config, job_uuid)
      version_file_state = check_file_md5('下载', local_version_path, config['version']['md5'], job_uuid)
      download_try_time += 1
    end

    unless version_file_state
      execute_job_logger("退出操作", job_uuid)
      exit 1 
    end
    
    target_file_path = File.join(config['app']['file_path'], config['app']['file_name'])
    delete_file_if_exists('部署', target_file_path, (config['version.backup_path'] || []).dig(0), job_uuid)

    unless File.exists?(config['app']['file_path'])
      FileUtils.mkdir_p(config['app']['file_path'])
      execute_job_logger("部署预检: 创建待部署的目录 #{config['app']['file_path']}", job_uuid)
    end

    FileUtils.cp(local_version_path, target_file_path)
    execute_job_logger("部署状态: 拷贝#{File.exists?(target_file_path) ? '成功' : 失败} #{target_file_path}", job_uuid)

    unless check_file_md5('部署', target_file_path, config['version']['md5'], job_uuid)
      execute_job_logger("退出操作", job_uuid)
      exit 1 
    end

    if File.extname(target_file_path).downcase == ".war" and File.exists?(target_file_path.sub(/\.war$/i, ''))
      target_file_folder = target_file_path.sub(/\.war$/i, '')
      FileUtils.rm_rf(target_file_folder)
      execute_job_logger("部署清理: 删除Tomcat旧目录 #{target_file_folder}", job_uuid)
    end

    (config['version.backup_path'] || []).each do |backup_path|
      unless File.exists?(backup_path)
        execute_job_logger("备份异常: 备份目录不存在 #{backup_path}", job_uuid)
        next
      end

      backup_file_path = File.join(backup_path, config['version']['version'] + '@' + config['app']['file_name'])
      FileUtils.cp(local_version_path, backup_file_path)
      execute_job_logger("版本备份: 备份#{File.exists?(backup_file_path) ? '成功' : 失败} #{backup_file_path}", job_uuid)
    end
    execute_job_logger('部署完成!', job_uuid)

    job_config_path = File.join(sandbox_path, 'job.json')
    job_config_hash = JSON.parse(File.read(job_config_path))
    Sypctl::Http.post_behavior({
      behavior: "成功执行任务「 #{job_config_hash['title']}」", 
      object_type: 'job', 
      object_id: job_config_hash['uuid']
    })
  end

  desc "app version config"
  task :config do
    key, value, job_uuid = ENV['key'], ENV['value'], ENV['uuid']
    job_uuid = value if job_uuid.empty?
    sandbox_path = File.join(ENV['RAKE_ROOT_PATH'], "db/jobs/#{job_uuid}")
    config_path = File.join(sandbox_path, 'config.json')

    execute_job_logger "Bundle 进程 ID: #{Process.pid}"
    if key == 'deploy'
      config = JSON.parse(File.read(config_path)) rescue {}
      deploy_app(sandbox_path, job_uuid)
    else
      execute_job_logger("初始化配置, #{key}: #{value}", job_uuid)

      config = JSON.parse(File.read(config_path)) rescue {}
      if key == 'version.backup_path'
        config[key] ||= []
        config[key].push(value)
        config[key] = config[key].uniq
      else
        config[key] = value
      end

      File.open(config_path, 'w:utf-8') { |file| file.puts(config.to_json) }
    end
  end
end