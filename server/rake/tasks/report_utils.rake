# encoding: utf-8
require 'active_support'
require 'active_support/core_ext/string'
require 'lib/utils/template_v1_engine'
require 'lib/utils/template_v2_engine'
require 'lib/utils/template_v3_engine'
require 'lib/utils/template_v4_engine'
require 'lib/utils/template_v5_engine'
require 'lib/utils/template_v10_engine'
require 'lib/utils/template_instance_methods'

namespace :report do
  namespace :utils do
    desc 'bundle exec rake report:utils:export report_id=1'
    task export: :environment do |t, args|
      include ::Template::InstanceMethods

      report_id = ENV['report_id'] || '-1'
      unless report = Report.find_by(report_id: report_id)
        puts "报表查询失败 report_id=#{report_id}"
        exit
      end

      sql_sentences = []
      # 导出报表配置
      sql_sentences.push <<-EOF.strip_heredoc
        delete from sys_template_reports where report_id = #{report_id};
        insert into sys_template_reports(report_id, template_id, content, title, created_at, updated_at)
        value(#{report.report_id}, #{report.template_id}, '#{report.content}', '#{report.title}', now(), now());
      EOF

      # 导出报表权限
      values = GroupReport.where(report_id: report.report_id).map do |gr|
        "(#{gr.report_id}, #{gr.group_id}, #{gr.template_id}, now(), now())"
      end
      sql_sentences.push <<-EOF.strip_heredoc
        delete from sys_group_reports where report_id = #{report_id};
        insert into sys_group_reports(report_id, group_id, template_id, created_at, updated_at)
        values
        #{values.join(",\n")};
      EOF

      File.open("report_#{report_id}_config.sql", "w:utf-8") do |file|
        file.puts sql_sentences.join("\n")
      end

      # 导出报表数据
      config_hash = ActiveRecord::Base.connection_config
      mysql_port = config_hash[:port] || 3306
      puts "mysqldump -h#{config_hash[:host]} -u#{config_hash[:username]} -p#{config_hash[:password]} -P#{mysql_port} #{config_hash[:database]} #{report.configuration_tables.join(' ')} > report_#{report_id}_data.sql"
    end

    def import_sql_file_command(sql_path, config)
      "mysql --host=#{config[:host]} --port=#{config[:port] || 3306} --user=#{config[:username]} --password=#{config[:password]} --database=#{config[:database]} < #{sql_path} > /dev/null 2>&1"
    end

    desc 'bundle exec rake report:utils:import report_id=1'
    task import: :environment do |t, args|
      include ::Template::InstanceMethods

      report_id = ENV['report_id'] || '-1'
      if !File.exists?("report_#{report_id}_config.sql") || !File.exists?("report_#{report_id}_data.sql")
        puts "report_#{report_id}_config.sql 或 report_#{report_id}_data.sql 文件不存在"
        exit
      end

      # 导出报表数据
      config_hash = ActiveRecord::Base.connection_config
      sql_command = import_sql_file_command("report_#{report_id}_config.sql", config_hash)
      cmd_state = run_command(sql_command).flatten.join
      puts sql_command
      puts cmd_state
      sql_command = import_sql_file_command("report_#{report_id}_data.sql", config_hash)
      cmd_state = run_command(sql_command).flatten.join
      puts sql_command
      puts cmd_state
    end

    desc 'bundle exec rake report:utils:config report_id=1'
    task config: :environment do |t, args|
      include ::Template::InstanceMethods

      report_id = ENV['report_id'] || '-1'
      unless report = Report.find_by(report_id: report_id)
        puts "报表查询失败 report_id=#{report_id}"
        exit
      end

      puts report.configuration_tables
    end
  end
end
