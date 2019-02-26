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
        next unless File.exists?(output_path)

        output_list = JSON.parse(File.read(output_path))
        table_rows = output_list.sort_by { |h| h['file_size'] }.map { |h| [h['host'], h['database'], h['file_name'], h['file_size'].to_i.number_to_human_size(true), "#{h['duration']}s"] }
        puts Terminal::Table.new(headings: %w(Host Database FileName FileSize Duration), rows: table_rows)
      end
    end

    def execute
      @backup_list.each do |backup_config|
        config = backup_config['config']
        client = Mysql2::Client.new(config)
        result = client.query("show databases")
        client.close

        backup_path = File.join(backup_config['backup_path'], "#{config['host']}-#{config['port'] || 3306}", Time.now.strftime('%y%m%d'))
        FileUtils.mkdir_p(backup_path) unless File.exists?(backup_path)
        output_path = File.join(backup_path, 'mysqldump.json')
        result.map { |h| h.values }.flatten.each do |database|
          next if (backup_config['ignore_databases'] || []).include?(database)

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

          file_path = File.join(backup_path, "#{database}.sql.tar.gz")
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
          puts "#{database}, #{state}"

          output_list = File.exists?(output_path) ? JSON.parse(File.read(output_path)) : []
          output_list.push(options)
          puts output_path
          File.open(output_path, 'w:utf-8') { |file| file.puts(output_list.to_json) }
        end
      end
    end

    alias_method :guard, :execute
  end
end

BackupMySQL.options(options)
BackupMySQL.send(options.keys.first)
