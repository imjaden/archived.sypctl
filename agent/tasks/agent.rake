# encoding: utf-8
require 'json'
require 'securerandom'

namespace :agent do
  desc "submit self info to server every 5 minutes"
  task guard: :environment do
    post_to_server_register unless File.exists?(agent_json_path)
    agent_json_hash = JSON.parse(IO.read(agent_json_path))
    post_to_server_register unless agent_json_hash["synced"]

    post_to_server_submitor
  end

  desc "submit service content and status data to server"
  task service: :environment do
    post_service_to_server_submitor
  end

  desc 'agent submit job execute status'
  task job: :environment do
    if ENV['uuid'].to_s.empty?
      puts "Error: 请提供 Job UUID 作为参数"
      exit
    end

    job_json_path = agent_root_join("jobs/sypctl-job-#{ENV['uuid']}.json")
    job_command_path = agent_root_join("jobs/sypctl-job-#{ENV['uuid']}.sh")
    job_output_path = agent_root_join("jobs/sypctl-job-#{ENV['uuid']}.sh-output")

    job_hash = JSON.parse(IO.read(job_json_path))
    job_hash['state'] = 'done'
    job_hash['output'] = File.exists?(job_output_path) ? IO.read(job_output_path) : "无输出"
    post_to_server_job(job_hash)
  end

  desc 'print aget regisiter info'
  task info: :environment do
    print_agent_info
  end

  desc 'print agent submitor log'
  task log: :environment do
    print_agent_log
  end

  desc 'print device uuid'
  task device_uuid: :environment do 
    platform = `uname -s`.strip
    klass = ['Utils', platform].inject(Object) { |obj, klass| obj.const_get(klass) }
    puts klass.device_uuid
  end

  desc 'print device info'
  task device: :environment do 
    submited_hash = print_agent_info(false)
    current_hash = agent_device_init_info

    rows = %w(hostname username password os_type os_version lan_ip wan_ip memory cpu disk).map do |key|
      [key, submited_hash[key], current_hash[key.to_sym]]
    end

    puts Time.now.strftime("timestamp: %Y-%m-%d %H:%M:%S")
    puts Terminal::Table.new(headings: %w(option submited current), rows: rows)
    puts "submited uuid: #{submited_hash['uuid']}"
    puts "current  uuid: #{current_hash[:uuid]}"
  end
end