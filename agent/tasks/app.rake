# encoding: utf-8
require 'json'
require 'httparty'
require 'fileutils'
require 'digest/md5'
require 'securerandom'

namespace :app do
  desc "app version config"
  task :config do
    tmp_path = File.join(ENV['RAKE_ROOT_PATH'], 'jobs/app-deploy-tmp')
    config_path = File.join(tmp_path, 'config.json')

    puts "Bundle 进程 ID: #{Process.pid}"
    key = ENV['key']
    value = ENV['value']
    if key == 'init'
      value = SecureRandom.uuid.gsub('-', '')
      FileUtils.rm_rf(tmp_path) if File.exists?(tmp_path)
      FileUtils.mkdir_p(tmp_path)
      puts "初始化部署, 临时分配 UUID: #{value}"
    else
      value ||= 'unset'
      FileUtils.mkdir_p(tmp_path) unless File.exists?(tmp_path)
      puts "初始化配置, #{key}: #{value}"
    end

    config = JSON.parse(File.read(config_path)) rescue {}
    if key == 'version.backup_path'
      config[key] ||= []
      config[key].push(value)
      config[key] = config[key].uniq
    else
      config[key] = value
    end

    File.open(config_path, 'w:utf-8') do |file|
      file.puts(config.to_json)
    end
  end

  def check_file_md5(label, path, md5)
    if File.exists?(path)
      local_md5 = Digest::MD5.file(path).hexdigest
      if md5 == local_md5
        puts "#{label}检查: 文件哈希一致 #{md5}"
      else
        puts "#{label}检查: 文件哈希不一致，期望 #{md5} 而实际是 #{local_md5}"
      end
    else
      puts "#{label}异常: 文件不存在 #{path}"
    end
  end

  def get_api_info(label, url)
    res = HTTParty.get(url)
    if res.code != 200
      puts "查询异常: 获取#{label}信息失败 - #{res.message}"
      puts "退出部署操作"
      return false
    end
    puts "查询成功: 获取应用信息"
    JSON.parse(res.body)['data']
  end

  def download_version_file(url, path)
    res, btime, ptime = nil, Time.now, Time.now
    puts "下载文件: 链接 #{url}"
    File.open(path, 'w:utf-8') do |file|
      puts '下载预告: 每五秒打印报告'
      res = HTTParty.get(url, stream_body: true) do |fragment|
        file.write(fragment.force_encoding('utf-8'))
        if Time.now - ptime >= 5
          puts "下载进度: 时间戳 #{Time.now.strftime('%y-%m-%d %H:%M:%S')}, 文件大小 #{File.size(path).number_to_human_size}"
          ptime = Time.now
        end
      end
    end
    puts "下载状态: #{res.success? ? '成功' : '失败'}"
    puts "下载报告: #{File.size(path).number_to_human_size}" if File.exists?(path)
    puts "下载用时: #{Time.now - btime}s"
  end

  def delete_file_if_exists(label, path, backup_path = nil)    
    return unless File.exists?(path)
    if backup_path && File.exists?(backup_path)
      backup_file_path = File.join(backup_path, Time.now.strftime('%y%m%d%H%M%S') + '-' + File.basename(path))
      FileUtils.mv(path, backup_file_path)
      puts "#{label}预检: 移动文件 #{path} 至 #{backup_file_path}"
    else
      FileUtils.rm_rf(path)
      puts "#{label}预检: 删除已存在文件 #{path}" 
    end
  end

  desc "app version deploy"
  task :deploy do
    tmp_path = File.join(ENV['RAKE_ROOT_PATH'], 'jobs/app-deploy-tmp')
    config_path = File.join(tmp_path, 'config.json')
    config = JSON.parse(File.read(config_path)) rescue {}

    puts "Bundle 进程 ID: #{Process.pid}"
    puts '部署开始: 时间戳 ' + Time.now.strftime('%y-%m-%d %H:%M:%S')
    if !config['app.uuid'] || !config['version.uuid']
      puts '配置异常: 应用/版本 UUID 未配置，退出操作'
      exit 1
    end
    
    data = get_api_info('应用', "#{ENV['SYPCTL-API']}/api/v1/app?uuid=#{config['app.uuid']}")
    exit 1 unless data
    config['app'] = data
    puts "应用信息:"
    puts "    - UUID: #{data['uuid']}"
    puts "    - 应用名称: #{data['name']}"
    puts "    - 文件类型: #{data['file_type']}"
    puts "    - 文件名称: #{data['file_name']}"
    puts "    - 部署目录: #{data['file_path']}"

    data = get_api_info('版本', "#{ENV['SYPCTL-API']}/api/v1/app/version?uuid=#{config['version.uuid']}")
    exit 1 unless data
    config['version'] = data
    puts "版本信息:"
    puts "    - UUID: #{data['uuid']}"
    puts "    - 版本名称: #{data['version']}"
    puts "    - 文件大小: #{data['file_size']}"
    puts "    - 文件名称: #{data['file_name']}"
    puts "    - 文件哈希: #{data['md5']}"
    puts "    - 下载链接: #{data['download_path']}"
    
    File.open(config_path, 'w:utf-8') do |file|
      file.puts(config.to_json)
    end

    btime = Time.now
    url = "#{ENV['SYPCTL-API']}#{config['version']['download_path']}"
    local_version_path = File.join(ENV['RAKE_ROOT_PATH'], 'jobs/app-deploy-tmp', config['version']['file_name'])

    delete_file_if_exists('下载', local_version_path)
    download_version_file(url, local_version_path)
    check_file_md5('下载', local_version_path, config['version']['md5'])
    
    target_file_path = File.join(config['app']['file_path'], config['app']['file_name'])
    delete_file_if_exists('部署', target_file_path, config['app']['file_path'])

    unless File.exists?(config['app']['file_path'])
      FileUtils.mkdir_p(config['app']['file_path'])
      puts "部署预检: 创建待部署的目录 #{config['app']['file_path']}"
    end
    FileUtils.cp(local_version_path, target_file_path)
    puts "部署状态: 拷贝#{File.exists?(target_file_path) ? '成功' : 失败} #{target_file_path}"

    check_file_md5('部署', target_file_path, config['version']['md5'])

    if config['version.backup_path']
      config['version.backup_path'].each do |backup_path|
        unless File.exists?(backup_path)
          puts "备份异常: 备份目录不存在 #{backup_path}"
          next
        end

        backup_file_path = File.join(backup_path, config['version']['version'] + '@' + config['app']['file_name'])
        FileUtils.cp(local_version_path, backup_file_path)
        puts "版本备份: 备份#{File.exists?(backup_file_path) ? '成功' : 失败} #{backup_file_path}"
      end
    end

    new_path = File.join(ENV['RAKE_ROOT_PATH'], 'jobs/version-' + config['version']['uuid'])
    FileUtils.rm_rf(new_path) if File.exists?(new_path)
    FileUtils.mv(tmp_path, new_path)

    puts "部署归档: 清理临时目录 #{tmp_path}"
    puts "部署归档: 归档存储目录 #{new_path}"
    puts '部署完成: 时间戳 ' + Time.now.strftime('%y-%m-%d %H:%M:%S')
  end
end