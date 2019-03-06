# encoding: utf-8
########################################
#  
#  BackupMySQL Manager v1.0
#
########################################
#
# 具体用法:
# $ ruby backup-mysql-tools.rb --help
# 
require 'json'
require 'mysql2'
require 'timeout'
require 'optparse'
require 'fileutils'
require 'digest/md5'
require 'securerandom'
require 'terminal-table'
require File.expand_path('../../../agent/lib/utils/http', __FILE__)
require File.expand_path('../../../agent/lib/utils/device', __FILE__)
require File.expand_path('../../../agent/lib/core_ext/numberic', __FILE__)

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: service-tools.rb [args]"
  opts.on('-h', '--help', '参数说明') do
    puts "备份 MySQL 数据库工具"
    puts opts
    exit 1
  end
  opts.on('-l', "--list", '查看备份配置') do |value|
    options[:list] = value
  end
  opts.on('-v', "--view", '执行今日备份状态') do |value|
    options[:view] = value
  end
  opts.on('-c', "--clean", '清理空文档') do |value|
    options[:clean] = value
  end
  opts.on('-s', "--state", '进程状态') do |value|
    options[:state] = value
  end
  opts.on('-e', "--execute", '执行备份操作') do |value|
    options[:execute] = value
  end
  opts.on('-g', "--guard", '守护备份操作，功能同 execute') do |value|
    options[:guard] = value
  end
end.parse!

puts `ruby #{__FILE__} -h` if options.keys.empty?

class BackupMySQL
  class << self
    def options(options)
      @options = options

      @config_path = '/etc/sypctl/backup-mysql.json'
      exit(1) unless File.exists?(@config_path)
        
      @backup_list = JSON.parse(File.read(@config_path))
      ENV["SYPCTL_API"] = ENV["SYPCTL_API_CUSTOM"] || "http://sypctl.com"
    end

    def list
      table_rows = @backup_list.map do |backup_config|
        config = backup_config['config']
        [backup_config['name'], config['host'], config['port'] || 3306, config['username'], backup_config['backup_path']]
      end
      puts Terminal::Table.new(headings: %w(Title Host Port UserName BackupPath), rows: table_rows)
    end

    def view
      @backup_list.each do |backup_config|
        config = backup_config['config']
        backup_path = File.join(backup_config['backup_path'], "#{config['host']}-#{config['port'] || 3306}", Time.now.strftime('%y%m%d'))
        FileUtils.mkdir_p(backup_path) unless File.exists?(backup_path)
        output_path = File.join(backup_path, 'mysqldump.json')
        databases_path = File.join(backup_path, 'databases.json')
        next unless File.exists?(output_path)

        backup_hash = JSON.parse(File.read(output_path))
        database_list = JSON.parse(File.read(databases_path))
        table_rows = backup_hash.values.sort_by { |h| h['backup_size'] }.map { |h| ["#{h['host']}:#{h['port']}", h['database_name'], h['backup_name'], h['backup_size'].to_i.number_to_human_size(true), "#{h['backup_duration']}s"] }
        puts Terminal::Table.new(headings: %w(Host Database FileName FileSize Duration), rows: table_rows)
        puts "total: #{table_rows.length} rows"
        puts "total: #{database_list.length} databases"
      end
    end

    def state
      pid_path = File.join(ENV['SYPCTL_HOME'] || ".", 'tmp/backup-mysql-ruby.pid')
      log_path = File.join(ENV['SYPCTL_HOME'] || ".", 'logs/backup-mysql.log')

      if File.exists?(pid_path)
        pid = File.read(pid_path).strip
        result = `ps ax | awk '{print $1}' | grep -e "^#{pid}$"`.strip
        if result.empty?
          puts "pid: aborted(#{pid})"
        else
          puts "pid: backuping(#{pid})"
        end
      else
        puts "pid: -"
      end

      if File.exists?(log_path)
        puts "log: #{log_path}"
      else
        puts "log: -"
      end
    end

    def clean
      @backup_list.each do |backup_config|
        config = backup_config['config']
        client = Mysql2::Client.new(config)
        databases = client.query("show databases").map { |h| h.values }.flatten
        client.close

        backup_path = File.join(backup_config['backup_path'], "#{config['host']}-#{config['port'] || 3306}", Time.now.strftime('%y%m%d'))
        FileUtils.mkdir_p(backup_path) unless File.exists?(backup_path)
        databases.each do |database|
          file_path = File.join(backup_path, "#{database}.sql.tar.gz")
          if File.exists?(file_path) && File.size(file_path) == 0
            puts "rm -f #{file_path}"
            FileUtils.rm_f(file_path)
          end
        end
      end
    end

    def execute
      pid_path = File.join(ENV['SYPCTL_HOME'] || ".", 'tmp/backup-mysql-ruby.pid')
      if File.exists?(pid_path)
        pid = File.read(pid_path).strip
        result = `ps ax | awk '{print $1}' | grep -e "^#{pid}$"`.strip
        unless result.empty?
          puts "pid: backuping(#{pid})"
          exit 1
        end
      end

      File.open(pid_path, 'w:utf-8') { |file| file.puts(Process.pid) }
      @backup_list.each do |backup_config|
        config = backup_config['config']
        client = Mysql2::Client.new(config)
        databases = client.query("show databases").map { |h| h.values }.flatten
        client.close

        backup_path = File.join(backup_config['backup_path'], "#{config['host']}-#{config['port'] || 3306}", Time.now.strftime('%y%m%d'))
        FileUtils.mkdir_p(backup_path) unless File.exists?(backup_path)
        output_path = File.join(backup_path, 'mysqldump.json')
        databases_path = File.join(backup_path, 'databases.json')
        File.open(databases_path, 'w:utf-8') { |file| file.puts(databases.to_json) }

        backup_hash, databases_btime = {}, Time.now
        backup_hash = JSON.parse(File.read(output_path)) rescue {} if File.exists?(output_path)
        databases.each do |database|
          next if (backup_config['ignore_databases'] || []).include?(database)

          file_path = File.join(backup_path, "#{database}.sql.tar.gz")
          if File.exists?(file_path) && backup_hash.dig(database, 'backup_state') == 'successfully' && backup_hash.dig(database, 'upload_state') == '上传成功'
            puts "#{database} backuped to #{file_path}"
            next
          end

          config["database"] = database
          client2 = Mysql2::Client.new(config)
          result2 = client2.query("show tables;")
          client2.close
          
          database_btime = Time.now
          ignore_tables = result2.map { |h| h.values }.flatten.select { |table| (backup_config['ignore_tables'] || []).any? { |regexp| table =~ Regexp::new(regexp)} }
          ignore_tables_sql = ignore_tables.map { |table| "--ignore-table=#{database}.#{table}" }.join(" ")
          bash_script = "mysqldump -h#{config['host']} -u#{config['username']} -p#{config['password']} -P#{config['port']} --default-character-set=utf8 #{database} #{ignore_tables_sql} > #{database}.sql 2>&1"

          state = 'successfully'
          begin
            `cd #{backup_path} && #{bash_script}`
          rescue => e
            state = 'failure'
            File.open(File.join(backup_path, "#{database}.sql"), 'w:utf-8') { |file| file.puts("error: #{e.message}\n\n#{config.to_json}\n\n#{bash_script}") }
          ensure
            `cd #{backup_path} && rm -f #{database}.sql.tar.gz`
            `cd #{backup_path} && tar -czvf #{database}.sql.tar.gz #{database}.sql && rm #{database}.sql`
          end

          options = {
            uuid: SecureRandom.uuid.gsub('-', ''),
            ymd: Time.now.strftime("%y%m%d"),
            host: config['host'],
            port: config['port'],
            database_name: database,
            backup_name: File.basename(file_path),
            backup_size: (File.exists?(file_path) ? File.size(file_path) : 0).number_to_human_size(true),
            backup_md5: (File.exists?(file_path) ? Digest::MD5.file(file_path).hexdigest : 'NotExist'),
            backup_time: database_btime.strftime('%y-%m-%d %H:%M:%S'),
            backup_duration: "#{(Time.now - database_btime).round(2)}s",
            backup_state: state,
            backup_command: "#{bash_script}",
            ignore_tables: ignore_tables
          }
          options[:description] = options.to_json
          Sypctl::Http.post_backup_mysql_day(options, {}, {print_log: true})

          params = {
            device_uuid: Sypctl::Device.uuid,
            host: "#{config['host']}-#{config['port']||3306}",
            ymd: Time.now.strftime("%y%m%d"),
            backup_name: File.basename(file_path),
            backup_md5: (File.exists?(file_path) ? Digest::MD5.file(file_path).hexdigest : 'NotExist'),
            backup_file: File.new(file_path, 'rb')
          }

          url = "#{ENV['SYPCTL_API']}/api/v1/upload/mysql_backup"
          response = Sypctl::Http.post(url, params)

          options.delete(:description)
          options[:upload_state] = response.dig('hash', 'message') || '上传响应为空'
          backup_hash[database] = options
          File.open(output_path, 'w:utf-8') { |file| file.puts(backup_hash.to_json) }

          puts "#{database}, backup #{state}, upload #{response.dig('hash', 'message')}, #{file_path}"
        end

        state_grouped_hash = backup_hash.values.group_by { |h| h[:backup_state] }
        options = {
          uuid: SecureRandom.uuid.gsub('-', ''),
          ymd: Time.now.strftime("%y%m%d"),
          database_count: databases.length,
          backup_count: backup_hash.keys.length,
          backup_duration: "#{(Time.now-databases_btime).round(2)}s",
          backup_size: du_sh(backup_path),
          backup_state: "数据库备份#{backup_hash.keys.length}个(共#{databases.length}个), 成功#{(state_grouped_hash['successfully']||[]).length}个,跳过(已备份)#{(state_grouped_hash['skip']||[]).length}个,失败#{(state_grouped_hash['failure']||[]).length}个"
        }

        Sypctl::Http.post_backup_mysql_meta(options, {}, {print_log: true})
        Sypctl::Http.post_behavior({
          behavior: "#{options[:backup_state]}, 用时#{(Time.now-databases_btime).round(2)}s", 
          object_type: 'mysql_backup', 
          object_id: "file_path"
        }, {}, {print_log: false})
      end

      FileUtils.rm_f(pid_path) if File.exists?(pid_path)
    end

    def du_sh(path)
      `du -sh #{path}`.split(/\s/)[0]
    rescue => e
      "error: #{e.message}"
    end

    alias_method :guard, :execute
  end
end

BackupMySQL.options(options)
BackupMySQL.send(options.keys.first)
