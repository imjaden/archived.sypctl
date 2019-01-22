# encoding: utf-8
########################################
#  
#  Service Manager v1.1
#
########################################
#
# 具体用法:
# $ ruby backup-file-tools.rb --help
# 
require 'json'
require 'timeout'
require 'optparse'
require 'rest-client'
require 'fileutils'
require 'digest/md5'
require 'terminal-table'
require 'net/http/post/multipart'
require File.expand_path('../../../agent/lib/utils/device', __FILE__)

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: service-tools.rb [args]"
  opts.on('-h', '--help', '参数说明') do
    puts "服务进程管理工具"
    puts opts
    exit
  end
  opts.on('-l', "--list", '查看备份列表') do |value|
    options[:list] = value
  end
  opts.on('-r', "--render", '查看元信息') do |value|
    options[:render] = value
  end
  opts.on('-e', "--execute", '执行备份操作') do |value|
    options[:execute] = value
  end
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

class BackupFile
  class << self
    def options(options)
      @options = options

      @db_path       = File.join(ENV['SYPCTL_HOME'], 'agent/file-backups')
      @archived_path = File.join(@db_path, 'archived')
      @db_hash_path  = File.join(@db_path, 'db.hash')
      @db_json_path  = File.join(@db_path, 'db.json')
      @synced_json_path = File.join(@db_path, 'synced.json')
      @synced_hash_path = File.join(@db_path, 'synced.hash')

      if !File.exists?(@db_hash_path) && !File.exists?(@db_json_path)
        puts "警告：本机暂未同步备份元信息"
        exit 1
      end

      @db_hash = File.read(@db_hash_path)
      @db_json = JSON.parse(File.read(@db_json_path))
      @synced_json = File.exists?(@synced_json_path) ? JSON.parse(File.read(@synced_json_path)) : {}
      @synced_hash = File.exists?(@synced_hash_path) ? File.read(@synced_hash_path).strip : "file-not-exist"

      FileUtils.mkdir_p(@archived_path) unless File.exists?(@archived_path)
      ENV["SYPCTL_API"] = ENV["SYPCTL_API_CUSTOM"] || "http://sypctl.com"
    end

    def render
      puts ENV['SYPCTL_API_CUSTOM']
      puts "元信息哈希: #{@db_hash}"
      puts "元信息路径: #{@db_json_path}"
      puts JSON.pretty_generate(@db_json)
    rescue => e
      puts e.message
    end

    def list
      puts "元信息哈希: #{@db_hash}"
      puts "元信息路径: #{@db_json_path}"
      table_rows = @db_json.map { |file| [file['uuid'], file['file_path'], file['description'], File.exists?(file['file_path']) ? '存在' : '不存在'] }
      puts Terminal::Table.new(headings: %w(UUID 文件路径 描述 是否存在), rows: table_rows)
    rescue => e
      puts "#{__FILE__}@#{__LINE__}: #{e.message}"
    end

    def execute
      @db_json.each do |file|
        next unless File.exists?(file['file_path'])

        file_md5 = Digest::MD5.file(file['file_path']).hexdigest
        next if @synced_json.dig(file['uuid'], 'md5') == file_md5
        
        archive_file_name = "#{file['uuid']}-#{File.mtime(file['file_path']).strftime('%Y%m%d%H%M%S')}-#{File.basename(file['file_path'])}"
        FileUtils.cp(file['file_path'], File.join(@archived_path, archive_file_name))

        options = {
          device_uuid: Utils::Device.uuid, 
          file_uuid: file['uuid'], 
          archive_file_name: archive_file_name,
          backup_file: File.new(file['file_path'], 'rb')
        }

        url = "#{ENV['SYPCTL_API']}/api/v1/upload/file_backup"
        res = RestClient.post(url, options).force_encoding('UTF-8')
        puts "#{res}, #{archive_file_name}"

        @synced_json[file['uuid']] ||= {synced: false}.merge(file)
        @synced_json[file['uuid']][:md5]     = file_md5
        @synced_json[file['uuid']][:archive_file_name] = archive_file_name
        @synced_json[file['uuid']][:message] = res
        @synced_json[file['uuid']][:synced]  = res.include?('上传成功')
        @synced_json[file['uuid']][:device_uuid] = Utils::Device.uuid
        @synced_json[file['uuid']][:timestamp]   = Time.now.to_i

        File.open(@synced_json_path, 'w:utf-8') { |file| file.puts(@synced_json.to_json) }
      end
    
      synced_hash = Digest::MD5.hexdigest(@synced_json.to_json)
      if @synced_hash != synced_hash
        url = "#{ENV['SYPCTL_API']}/api/v1/update/file_backup"
        options = {
          device_uuid: Utils::Device.uuid,
          file_backup_config: @db_json.to_json,
          file_backup_monitor: @synced_json.to_json
        }
        res = RestClient.post(url, options).force_encoding('UTF-8')
        puts "synced_hash now: #{synced_hash}"
        puts "synced_hash old: #{@synced_hash}"
        puts "#{res}, #{@synced_hash_path}"

        File.open(@synced_hash_path, 'w:utf-8') { |file| file.puts(synced_hash) } if res.include?('更新成功')
      end
    end
  end
end

BackupFile.options(options)
BackupFile.send(options.keys.first)
