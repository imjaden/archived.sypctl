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

      @config_path    = '/etc/sypctl/backup-mysql.json'
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

        output_list = JSON.parse(File.read(output_path))
        database_list = JSON.parse(File.read(databases_path))
        table_rows = output_list.sort_by { |h| h['file_size'] }.map { |h| [h['host'], h['database'], h['file_name'], h['file_size'].to_i.number_to_human_size(true), "#{h['duration']}s"] }
        puts Terminal::Table.new(headings: %w(Host Database FileName FileSize Duration), rows: table_rows)
        puts "total: #{table_rows.length} rows"
        puts "total: #{database_list.length} databases"
      end
    end

    def state
      pid_path = File.join(ENV['SYPCTL_HOME'], 'tmp/backup-mysql-ruby.pid')
      log_path = File.join(ENV['SYPCTL_HOME'], 'logs/backup-mysql.log')

      if File.exists?(pid_path)
        pid = File.read(pid_path).strip
        result = `ps ax | awk '{print $1}' | grep -e "^#{pid}$"`.strip
        if result.empty?
          puts "backup mysql aborted(#{pid})"
        else
          puts "backuping mysql(#{pid})"
        end
      else
        puts "no backup mysql process"
      end

      if File.exists?(log_path)
        puts "log path: #{log_path}"
      else
        puts "no log"
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
      pid_path = File.join(ENV['SYPCTL_HOME'], 'tmp/backup-mysql-ruby.pid')
      if File.exists?(pid_path)
        pid = File.read(pid_path).strip
        result = `ps ax | awk '{print $1}' | grep -e "^#{pid}$"`.strip
        unless result.empty?
          puts "backuping mysql(#{pid})..."
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

        databases.each do |database|
          next if (backup_config['ignore_databases'] || []).include?(database)

          file_path = File.join(backup_path, "#{database}.sql.tar.gz")
          if File.exists?(file_path)
            puts "#{database} backuped to #{backup_path}"
            next
          end

          config["database"] = database
          client2 = Mysql2::Client.new(config)
          result2 = client2.query("show tables;")
          client2.close
          
          begin_time = Time.now
          ignore_tables = result2.map { |h| h.values }.flatten.select { |table| (backup_config['ignore_tables'] || []).any? { |regexp| table =~ Regexp::new(regexp)} }
          ignore_tables_sql = ignore_tables.map { |table| "--ignore-table=#{database}.#{table}" }.join(" ")
          bash_script = "mysqldump -h#{config['host']} -u#{config['username']} -p#{config['password']} -P#{config['port']} #{database} #{ignore_tables_sql} > #{database}.sql 2>&1"

          state = 'successfully'
          begin
            `#{bash_script} && tar -czvf #{database}.sql.tar.gz #{database}.sql && mv #{database}.sql.tar.gz #{backup_path} && rm -f #{database}.sql`
          rescue => e
            state = "error: #{e.message}"
          end

          file_size = File.exists?(file_path) ? File.size(file_path) : 0
          options = {
            host: config['host'],
            database: database,
            file_name: "#{database}.sql.tar.gz",
            file_size: file_size,
            ignore_tables: ignore_tables,
            mysqldump_command: "#{bash_script}",
            begin_time: begin_time.strftime('%y-%m-%d %H:%M:%S'),
            duration: Time.now - begin_time,
            state: state 
          }
          output_list = File.exists?(output_path) ? JSON.parse(File.read(output_path)) : []
          output_list.push(options)
          File.open(output_path, 'w:utf-8') { |file| file.puts(output_list.to_json) }

          puts "#{database}, #{state}"
          puts output_path
        end
      end

      FileUtils.rm_f(pid_path) if File.exists?(pid_path)
    end

    alias_method :guard, :execute
  end
end

BackupMySQL.options(options)
BackupMySQL.send(options.keys.first)
