# encoding: utf-8
require 'json'
require 'httparty'
require 'fileutils'
require 'digest/md5'
require 'securerandom'

namespace :app do
  def _timestamp
    Time.now.strftime('%y-%m-%d %H:%M:%S')
  end

  def execute_job_logger(info, job_uuid = nil)
    message = "#{_timestamp} - #{info}"
    if job_uuid
      output_path = File.join(ENV['RAKE_ROOT_PATH'], "jobs/#{job_uuid}/job.output")
      File.open(output_path, 'a+:utf-8') { |file| file.puts(message) }

      sandbox_path = File.join(ENV['RAKE_ROOT_PATH'], "jobs/#{job_uuid}")
      job_output_path = File.join(sandbox_path, 'job.output')
      job_output = File.exists?(job_output_path) ? IO.read(job_output_path) : "无输出"
      post_to_server_job({uuid: job_uuid, state: 'executing', output: job_output})
    else
      puts message
    end
  rescue => e
    puts "#{__FILE__}@#{__LINE__}: #{e.message}"
  end

  def check_file_md5(label, path, md5, job_uuid)
    if File.exists?(path)
      local_md5 = Digest::MD5.file(path).hexdigest
      if md5 == local_md5
        execute_job_logger("#{label}检查: 文件哈希一致 #{md5}", job_uuid)
      else
        execute_job_logger("#{label}检查: 文件哈希不一致，期望 #{md5} 而实际是 #{local_md5}", job_uuid)
      end
    else
      execute_job_logger("#{label}异常: 文件不存在 #{path}", job_uuid)
    end
  end

  def get_api_info(label, url, job_uuid)
    res = HTTParty.get(url)
    if res.code != 200
      execute_job_logger("查询异常: 获取#{label}信息失败 - #{res.message}", job_uuid)
      execute_job_logger("- 请求链接: #{url}", job_uuid)
      execute_job_logger("- 查询描述: #{res.message}", job_uuid)
      execute_job_logger("退出部署操作", job_uuid)
      return false
    end
    execute_job_logger("查询成功: 获取应用信息", job_uuid)
    JSON.parse(res.body)['data']
  end

  def download_version_file(url, path, job_uuid)
    res, btime, ptime = nil, Time.now, Time.now
    execute_job_logger("下载文件: 链接 #{url}", job_uuid)
    File.open(path, 'w:utf-8') do |file|
      execute_job_logger('下载预告: 每十秒打印报告', job_uuid)
      res = HTTParty.get(url, stream_body: true) do |fragment|
        file.write(fragment.force_encoding('utf-8'))
        if Time.now - ptime > 10
          execute_job_logger("已下载文件大小 #{File.exists?(path) ? File.size(path).number_to_human_size : '0'}", job_uuid)
          ptime = Time.now
        end
      end
    end
    execute_job_logger("下载状态: #{res.success? ? '成功' : '失败'}", job_uuid)
    execute_job_logger("下载报告: #{File.size(path).number_to_human_size}", job_uuid) if File.exists?(path)
    execute_job_logger("下载用时: #{Time.now - btime}s", job_uuid)
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

    data = get_api_info('应用', "#{ENV['SYPCTL-API']}/api/v1/app?uuid=#{config['app.uuid']}", job_uuid)
    exit 1 unless data

    config['app'] = data
    execute_job_logger("应用信息:", job_uuid)
    execute_job_logger("    - UUID: #{data['uuid']}", job_uuid)
    execute_job_logger("    - 应用名称: #{data['name']}", job_uuid)
    execute_job_logger("    - 文件类型: #{data['file_type']}", job_uuid)
    execute_job_logger("    - 文件名称: #{data['file_name']}", job_uuid)
    execute_job_logger("    - 部署目录: #{data['file_path']}", job_uuid)

    data = get_api_info('版本', "#{ENV['SYPCTL-API']}/api/v1/app/version?uuid=#{config['version.uuid']}", job_uuid)
    exit 1 unless data

    config['version'] = data
    execute_job_logger("版本信息:", job_uuid)
    execute_job_logger("    - UUID: #{data['uuid']}", job_uuid)
    execute_job_logger("    - 版本名称: #{data['version']}", job_uuid)
    execute_job_logger("    - 文件大小: #{data['file_size']}", job_uuid)
    execute_job_logger("    - 文件名称: #{data['file_name']}", job_uuid)
    execute_job_logger("    - 文件哈希: #{data['md5']}", job_uuid)
    execute_job_logger("    - 下载链接: #{data['download_path']}", job_uuid)
    
    File.open(config_path, 'w:utf-8') { |file| file.puts(config.to_json) }

    btime = Time.now
    url = "#{ENV['SYPCTL-API']}#{config['version']['download_path']}"
    local_version_path = File.join(sandbox_path, config['version']['file_name'])

    delete_file_if_exists('下载', local_version_path, job_uuid)
    download_version_file(url, local_version_path, job_uuid)
    check_file_md5('下载', local_version_path, config['version']['md5'], job_uuid)
    
    target_file_path = File.join(config['app']['file_path'], config['app']['file_name'])
    delete_file_if_exists('部署', target_file_path, (config['version.backup_path'] || []).dig(0), job_uuid)

    unless File.exists?(config['app']['file_path'])
      FileUtils.mkdir_p(config['app']['file_path'])
      execute_job_logger("部署预检: 创建待部署的目录 #{config['app']['file_path']}", job_uuid)
    end
    FileUtils.cp(local_version_path, target_file_path)
    execute_job_logger("部署状态: 拷贝#{File.exists?(target_file_path) ? '成功' : 失败} #{target_file_path}", job_uuid)

    check_file_md5('部署', target_file_path, config['version']['md5'], job_uuid)

    if config['version.backup_path']
      config['version.backup_path'].each do |backup_path|
        unless File.exists?(backup_path)
          execute_job_logger("备份异常: 备份目录不存在 #{backup_path}", job_uuid)
          next
        end

        backup_file_path = File.join(backup_path, config['version']['version'] + '@' + config['app']['file_name'])
        FileUtils.cp(local_version_path, backup_file_path)
        execute_job_logger("版本备份: 备份#{File.exists?(backup_file_path) ? '成功' : 失败} #{backup_file_path}", job_uuid)
      end
    end

    execute_job_logger("部署归档: 清理沙盒目录 #{sandbox_path}", job_uuid)
    execute_job_logger('部署完成!', job_uuid)
  end

  desc "app version config"
  task :config do
    key, value, job_uuid = ENV['key'], ENV['value'], ENV['uuid']
    job_uuid = value if job_uuid.empty?
    sandbox_path = File.join(ENV['RAKE_ROOT_PATH'], "jobs/#{job_uuid}")
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