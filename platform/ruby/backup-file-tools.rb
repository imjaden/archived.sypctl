# encoding: utf-8
########################################
#  
#  BackupFile Manager v1.2
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
  opts.on('-s', "--status", '查看文件状态') do |value|
    options[:status] = value
  end
  opts.on('-g', "--guard", '守护备份操作，功能同 execute') do |value|
    options[:guard] = value
  end
  opts.on('-f', "--force", '强制同步文件') do |value|
    options[:force] = value
  end
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

class BackupFile
  class << self
    def options(options)
      @options = options

      @db_path = File.join(ENV['SYPCTL_HOME'], 'agent/db/file-backups')
      @db_jmd5_path = File.join(@db_path, 'db.jmd5')
      @db_hash_path = File.join(@db_path, 'db.json')
      @db_sync_path = File.join(@db_path, 'db.sync')
      @snapshots_path = File.join(@db_path, 'snapshots')

      if !File.exists?(@db_jmd5_path) || !File.exists?(@db_hash_path)
        puts "Warning：本机暂未同步备份元信息\n退出操作"
        exit 1
      end

      FileUtils.mkdir_p(@db_path) unless File.exists?(@db_path)
      FileUtils.mkdir_p(@snapshots_path) unless File.exists?(@snapshots_path)
      ENV["SYPCTL_API"] = ENV["SYPCTL_API_CUSTOM"] || "http://sypctl.com"

      @db_jmd5 = File.read(@db_jmd5_path).strip
      @db_hash = JSON.parse(File.read(@db_hash_path))
      @db_sync = File.read(@db_sync_path).strip rescue ""
    end

    def render
      puts ENV['SYPCTL_API']
      puts "元信息哈希: #{@db_jmd5}"
      puts "元信息路径: #{@db_hash_path}"
      # puts JSON.pretty_generate(@db_json)
    rescue => e
      puts e.message
    end

    def list
      puts "元信息哈希: #{@db_jmd5}"
      puts "元信息路径: #{@db_hash_path}"
      table_rows = @db_hash.map do |file|
        if File.exists?(file['backup_path']) 
          file_state = File.file?(file['backup_path']) ? 'File' : 'Dir'
        else
          file_state = 'NO'
        end

        [file['backup_uuid'], file['backup_path'], file_state]
      end
      puts Terminal::Table.new(headings: %w(UUID 文件路径 状态), rows: table_rows)
    rescue => e
      puts "#{__FILE__}@#{__LINE__}: #{e.message}"
    end

    def execute
      is_global_backup_files_updated = false

      # 备份文件元信息DB哈希改变时，重新扫描上传备份文件
      if @db_jmd5 != @db_sync
        is_global_backup_files_updated = true

        snapshot_instances_path = File.join(@db_path, "*-snapshot.json")
        Dir.glob(snapshot_instances_path).each { |snapshot_instance_path| FileUtils.rm(snapshot_instance_path) }
      end

      snapshots_hash = @db_hash.map.with_index do |record, backup_index|
        next unless File.exists?(record['backup_path'])

        is_backup_files_updated = false
        snapshot_instance_path = File.join(@db_path, "#{record['backup_uuid']}-snapshot.json")
        snapshot_instance_hash = File.exists?(snapshot_instance_path) ? JSON.parse(File.read(snapshot_instance_path)) : record
        
        snapshot_instance_hash['device_uuid'] = Sypctl::Device.uuid
        snapshot_instance_hash['file_type'] = 'file'
        snapshot_instance_hash['file_count'] = 1
        snapshot_instance_hash['file_tree'] = `tree #{record['backup_path']}`.to_s.strip
        snapshot_instance_hash['file_list'] ||= {}

        upload_options = {
          device_uuid: Sypctl::Device.uuid, 
          backup_uuid: record['backup_uuid'],
          backup_path: record['backup_path']
        }
        glob_files = [record['backup_path']]
        if File.directory?(record['backup_path']) 
          glob_files = _directiory_glob_files(record['backup_path'])

          snapshot_instance_hash['file_type'] = 'directory'
          snapshot_instance_hash['file_count'] = glob_files.count
          glob_files.each_with_object({}) do |filepath, glob_hash|
            file_md5 = Digest::MD5.file(filepath).hexdigest
            path_md5 = Digest::MD5.hexdigest(filepath)
            
            next if snapshot_instance_hash['file_list'][filepath] && snapshot_instance_hash['file_list'][filepath]['jmd5'] == file_md5 && snapshot_instance_hash['file_list'][filepath]['synced'] == true 

            is_backup_files_updated = true
            snapshot_filename = "#{path_md5}-#{File.mtime(filepath).to_i}-#{File.basename(filepath)}"
            FileUtils.cp(filepath, File.join(@snapshots_path, snapshot_filename))

            upload_options[:file_object] = File.new(filepath, 'rb')
            upload_options[:file_md5] = file_md5
            upload_options[:file_mtime] = File.mtime(filepath).to_i
            upload_options[:file_size] = File.size(filepath).to_i.number_to_human_size(true)
            upload_options[:snapshot_filename] = snapshot_filename

            url = "#{ENV['SYPCTL_API']}/api/v1/upload/backup_file"
            response = Sypctl::Http.post(url, upload_options)
            puts "post backup_file, #{response['hash']['message']}, #{snapshot_filename}"

            backup_hash = {
              synced: ((response || {}).dig('hash', 'message') || '').include?('上传成功'),
              mtime: File.mtime(filepath).to_i,
              jmd5: file_md5,
              pmd5: path_md5
            }
            snapshot_instance_hash['file_list'][filepath] = backup_hash
            snapshot_instance_hash['history'][filepath] = backup_hash

            # 数据写入磁盘
            File.open(snapshot_instance_path, 'w:utf-8') { |file| file.puts(snapshot_instance_hash.to_json) }
            snapshot_instance_hash = JSON.parse(File.read(snapshot_instance_path))

            Sypctl::Http.post_behavior({
              behavior: "监测到文档更新并上传服务器，#{snapshot_filename}", 
              object_type: 'file_backup', 
              object_id: record['backup_uuid']
            })
          end
        else
          filepath = record['backup_path']
          file_md5 = Digest::MD5.file(filepath).hexdigest
          path_md5 = Digest::MD5.hexdigest(filepath)

          next if snapshot_instance_hash['file_list'][filepath] && snapshot_instance_hash['file_list'][filepath]['jmd5'] == file_md5 && snapshot_instance_hash['file_list'][filepath]['synced'] == true 

          is_backup_files_updated = true
          snapshot_filename = "#{path_md5}-#{File.mtime(filepath).to_i}-#{File.basename(filepath)}"
          FileUtils.cp(filepath, File.join(@snapshots_path, snapshot_filename))

          upload_options[:file_object] = File.new(filepath, 'rb')
          upload_options[:file_md5] = file_md5
          upload_options[:file_mtime] = File.mtime(filepath).to_i
          upload_options[:file_size] = File.size(filepath).to_i.number_to_human_size(true)
          upload_options[:snapshot_filename] = snapshot_filename

          url = "#{ENV['SYPCTL_API']}/api/v1/upload/backup_file"
          response = Sypctl::Http.post(url, upload_options)
          puts "post backup_file, #{response['hash']['message']}, #{snapshot_filename}"
          
          backup_hash = {
            synced: ((response || {}).dig('hash', 'message') || '').include?('上传成功'),
            mtime: File.mtime(filepath).to_i,
            jmd5: file_md5,
            pmd5: path_md5
          }
          snapshot_instance_hash['file_list'][filepath] = backup_hash
          snapshot_instance_hash['history'][filepath] = backup_hash

          # 数据写入磁盘
          File.open(snapshot_instance_path, 'w:utf-8') { |file| file.puts(snapshot_instance_hash.to_json) }
          snapshot_instance_hash = JSON.parse(File.read(snapshot_instance_path))

          Sypctl::Http.post_behavior({
            behavior: "监测到文档更新并上传服务器，#{snapshot_filename}", 
            object_type: 'file_backup', 
            object_id: record['backup_uuid']
          })
        end

        # 清理filelist中被删除的文件
        deleted_files = snapshot_instance_hash['file_list'].keys - glob_files
        unless deleted_files.empty?
          is_backup_files_updated = true
          deleted_files.each { |deleted_file| snapshot_instance_hash['file_list'].delete(deleted_file) }
          File.open(snapshot_instance_path, 'w:utf-8') { |file| file.puts(snapshot_instance_hash.to_json) }
        end

        if is_backup_files_updated
          url = "#{ENV['SYPCTL_API']}/api/v1/upload/backup_snapshot"
          response = Sypctl::Http.post(url, snapshot_instance_hash)
          puts "post upload/backup_snapshot, #{response['hash']['message']}"
        end
        is_global_backup_files_updated = true if is_backup_files_updated
        snapshot_instance_hash
      end

      if is_global_backup_files_updated
        url = "#{ENV['SYPCTL_API']}/api/v1/update/backup_snapshot"
        response = Sypctl::Http.post(url, {device_uuid: Sypctl::Device.uuid, file_backup_config: @db_hash.to_json, file_backup_monitor: snapshots_hash.compact.to_json})
        puts "post update/backup_snapshot, #{response['hash']['message']}"

        File.open(@db_sync_path, 'w:utf-8') { |file| file.puts(@db_jmd5) }
      end
    end
    alias_method :guard, :execute

    def force
      # clean file snapshot cached
      snapshots_hash = @db_hash.map.with_index do |record, backup_index|
        next unless File.exists?(record['backup_path'])

        snapshot_instance_path = File.join(@db_path, "#{record['backup_uuid']}-snapshot.json")
        File.delete(snapshot_instance_path) if File.exists?(snapshot_instance_path)
      end

      # upload file and cache snapshot
      execute
    end

    def status
      snapshots_hash = @db_hash.map.with_index do |record, backup_index|
        unless File.exists?(record['backup_path'])
          puts "NotExist, #{record['backup_path']}"
          next
        end

        snapshot_instance_path = File.join(@db_path, "#{record['backup_uuid']}-snapshot.json")
        snapshot_instance_hash = File.exists?(snapshot_instance_path) ? JSON.parse(File.read(snapshot_instance_path)) : record
        snapshot_instance_hash['file_list'] ||= {}
        glob_files = [record['backup_path']]
        if File.directory?(record['backup_path']) 
          glob_files = _directiory_glob_files(record['backup_path'])
          puts "Directory, #{glob_files.count} files, #{record['backup_path']}"

          glob_files.each_with_object({}) do |filepath, glob_hash|
            file_md5 = Digest::MD5.file(filepath).hexdigest
            path_md5 = Digest::MD5.hexdigest(filepath)
            
            if snapshot_instance_hash['file_list'][filepath] && snapshot_instance_hash['file_list'][filepath]['jmd5'] == file_md5 && snapshot_instance_hash['file_list'][filepath]['synced'] == true 
              puts "  File, Cached, #{File.mtime(filepath).strftime('%y/%m/%d %H:%M:%S')}, #{filepath}"
            else
              puts "  File, Updated, #{File.mtime(filepath).strftime('%y/%m/%d %H:%M:%S')}, #{filepath}"
            end 
          end
        else
          filepath = record['backup_path']
          file_md5 = Digest::MD5.file(filepath).hexdigest
          path_md5 = Digest::MD5.hexdigest(filepath)

          if snapshot_instance_hash['file_list'][filepath] && snapshot_instance_hash['file_list'][filepath]['jmd5'] = file_md5 && snapshot_instance_hash['file_list'][filepath]['synced'] == true 
            puts "File, Cached, #{File.mtime(filepath).strftime('%y/%m/%d %H:%M:%S')}, #{filepath}"
          else
            puts "File, Updated, #{File.mtime(filepath).strftime('%y/%m/%d %H:%M:%S')}, #{filepath}"
          end
        end
      end
    end

    def _directiory_glob_files(directory_path, files = [])
      Dir.glob(File.join(directory_path, "*")).each do |filepath|
        if File.directory?(filepath)
          files = _directiory_glob_files(filepath, files)
        elsif File.file?(filepath)
          files.push(filepath)
        end
      end
      return files
    end

  end
end

BackupFile.options(options)
BackupFile.send(options.keys.first)
