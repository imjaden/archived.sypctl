# encoding: utf-8
########################################
#  
#  FileBackup Manager v1.1
#
########################################
#
# 具体用法:
# $ ruby backup-file-tools.rb --help
# 
require 'json'
require 'timeout'
require 'optparse'
require 'fileutils'
require 'digest/md5'
require 'terminal-table'
require File.expand_path('../../../agent/lib/utils/http', __FILE__)
require File.expand_path('../../../agent/lib/utils/device', __FILE__)
require File.expand_path('../../../agent/lib/core_ext/numberic', __FILE__)

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: service-tools.rb [args]"
  opts.on('-h', '--help', '参数说明') do
    puts "服务进程管理工具"
    puts opts
    exit 1
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
  opts.on('-g', "--guard", '守护备份操作，功能同 execute') do |value|
    options[:guard] = value
  end
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

class BackupFile
  class << self
    def options(options)
      @options = options

      @db_path       = File.join(ENV['SYPCTL_HOME'], 'agent/db/file-backups')
      @archived_path = File.join(@db_path, 'archived')
      @db_hash_path  = File.join(@db_path, 'db.hash')
      @db_json_path  = File.join(@db_path, 'db.json')
      @synced_json_path = File.join(@db_path, 'synced.json')
      @synced_hash_path = File.join(@db_path, 'synced.hash')

      if !File.exists?(@db_hash_path) || !File.exists?(@db_json_path)
        puts "警告：本机暂未同步备份元信息\n退出操作"
        exit 1
      end

      @db_hash = File.read(@db_hash_path)
      @db_json = JSON.parse(File.read(@db_json_path))
      @synced_json = File.exists?(@synced_json_path) ? JSON.parse(File.read(@synced_json_path)) : {}
      @synced_hash = File.exists?(@synced_hash_path) ? File.read(@synced_hash_path).strip : "FileNotExist"

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
      table_rows = @db_json.map do |file|
        if File.exists?(file['file_path']) 
          file_state = File.file?(file['file_path']) ? 'File' : 'Dir'
        else
          file_state = 'NO'
        end

        [file['uuid'], file['file_path'], file_state]
      end
      puts Terminal::Table.new(headings: %w(UUID 文件路径 状态), rows: table_rows)
    rescue => e
      puts "#{__FILE__}@#{__LINE__}: #{e.message}"
    end

    def execute
      @db_json.each do |record|
        next unless File.exists?(record['file_path'])

        uuid = record['uuid']
        if File.directory?(record['file_path']) 
          options = {
            device_uuid: Sypctl::Device.uuid, 
            file_uuid: uuid,
          }
          files_md5 = @synced_json.dig(uuid, 'files_md5') || {}
          file_list = @synced_json.dig(uuid, 'file_list') || {}
          Dir.glob(File.join(record['file_path'], "*.*")).each do |file_path|
            next if File.directory?(file_path)

            file_md5 = Digest::MD5.file(file_path).hexdigest
            file_name = File.basename(file_path)
            next if files_md5.dig(file_name) == file_md5 && file_list.dig(file_name, 'synced')
            
            archive_file_name = "#{uuid}-#{File.mtime(file_path).strftime('%Y%m%d%H%M%S')}-#{File.basename(file_path)}"
            FileUtils.cp(file_path, File.join(@archived_path, archive_file_name))

            options[:archive_file_name] = archive_file_name
            options[:backup_file] = File.new(file_path, 'rb')

            url = "#{ENV['SYPCTL_API']}/api/v1/upload/file_backup"
            response = Sypctl::Http.post(url, options)
            puts "#{response['hash']['message']}, #{file_path}"

            files_md5[file_name] = file_md5
            file_list[file_name] = {
              synced: response['hash']['message'].include?('上传成功'),
              file_name: file_name,
              file_md5: file_md5,
              file_mtime: File.mtime(file_path).to_i,
              file_size: File.size(file_path).to_i.number_to_human_size(true),
              archive_file_name: archive_file_name
            }

            @synced_json[uuid] = {
              synced: true,
              uuid: uuid,
              file_path: record['file_path'],
              description: record['description'],
              message: response['hash']['message'],
              files_md5: files_md5,
              file_list: file_list
            }

            File.open(@synced_json_path, 'w:utf-8') { |file| file.puts(@synced_json.to_json) }
            @synced_json = JSON.parse(File.read(@synced_json_path))
          end
        else
          file_path = record['file_path']
          file_md5 = Digest::MD5.file(file_path).hexdigest
          next if @synced_json.dig(uuid, 'md5') == file_md5
          
          archive_file_name = "#{uuid}-#{File.mtime(file_path).strftime('%Y%m%d%H%M%S')}-#{File.basename(file_path)}"
          FileUtils.cp(file_path, File.join(@archived_path, archive_file_name))

          options = {
            device_uuid: Sypctl::Device.uuid, 
            file_uuid: uuid, 
            archive_file_name: archive_file_name,
            backup_file: File.new(file_path, 'rb')
          }

          url = "#{ENV['SYPCTL_API']}/api/v1/upload/file_backup"
          response = Sypctl::Http.post(url, options)
          puts "#{response['hash']['message']}, #{archive_file_name}"

          @synced_json[uuid] ||= {synced: false}.merge(record)
          @synced_json[uuid][:md5]         = file_md5
          @synced_json[uuid][:message]     = response['hash']['message']
          @synced_json[uuid][:synced]      = response['hash']['message'].include?('上传成功')
          @synced_json[uuid][:file_mtime]  = File.mtime(file_path).to_i
          @synced_json[uuid][:file_size]   = File.size(file_path).to_i.number_to_human_size(true)
          @synced_json[uuid][:device_uuid] = Sypctl::Device.uuid
          @synced_json[uuid][:archive_file_name] = archive_file_name

          File.open(@synced_json_path, 'w:utf-8') { |file| file.puts(@synced_json.to_json) }
          @synced_json = JSON.parse(File.read(@synced_json_path))
        end
      end
    
      file_uuids = @db_json.map { |hsh| hsh['uuid'] }
      @synced_json = JSON.parse(File.read(@synced_json_path))
      deprecated_uuids = (@synced_json.keys - file_uuids)
      deprecated_uuids.each { |file_uuid| @synced_json.delete(file_uuid) }
      File.open(@synced_json_path, 'w:utf-8') { |file| file.puts(@synced_json.to_json) } unless deprecated_uuids.empty?

      synced_hash = Digest::MD5.hexdigest(@synced_json.to_json)
      if @synced_hash != synced_hash
        url = "#{ENV['SYPCTL_API']}/api/v1/update/file_backup"
        options = {
          device_uuid: Sypctl::Device.uuid,
          file_backup_config: @db_json.to_json,
          file_backup_monitor: @synced_json.to_json
        }
        response = Sypctl::Http.post(url, options)
        puts "synced_hash now: #{synced_hash}"
        puts "synced_hash old: #{@synced_hash}"
        puts "#{response['hash']['message']}, #{@synced_hash_path}"

        File.open(@synced_hash_path, 'w:utf-8') { |file| file.puts(synced_hash) } if response['hash']['message'].include?('更新成功')
      end
    end

    alias_method :guard, :execute
  end
end

BackupFile.options(options)
BackupFile.send(options.keys.first)
