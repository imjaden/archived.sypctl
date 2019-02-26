# encoding: utf-8
require 'json'
require 'securerandom'

namespace :agent do
  desc "submit self info to server every 5 minutes"
  task guard: :environment do
    agent_json_hash = JSON.parse(IO.read(agent_json_path)) rescue {}
    post_to_server_register if !agent_json_hash['synced'] || ENV['FORCE_SYNC_AGENT_INFO'] == 'true'

    post_to_server_submitor
    refresh_agent_system_meta
  end

  desc 'agent submit job execute status'
  task job: :environment do
    if ENV['uuid'].to_s.empty?
      puts "Error: 请提供 Job UUID 作为参数"
      exit
    end

    sandbox_path = File.join(ENV['RAKE_ROOT_PATH'], "db/jobs/#{ENV['uuid']}")
    job_json_path = File.join(sandbox_path, 'job.json')
    job_output_path = File.join(sandbox_path, 'job.output')
    job_output_bundle_path = File.join(sandbox_path, 'job.output.bundle')
    job_output = File.exists?(job_output_path) ? IO.read(job_output_path) : "无输出"
    job_bundle_output = File.exists?(job_output_bundle_path) ? IO.read(job_output_bundle_path) : "无输出"
    options = JSON.parse(File.read(job_json_path))
    options['state'] = 'done'
    options['output'] = job_bundle_output + "\n\n#{'-' * 20}\n\n" + job_output
    post_to_server_job(options)
  end

  desc 'print aget regisiter info'
  task info: :environment do
    print_agent_regisitered_info
  end

  desc 'print agent will register info'
  task render: :environment do
    print_agent_will_regisiter_info
  end

  desc 'print agent submitted log'
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