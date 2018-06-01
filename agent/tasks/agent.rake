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

  desc 'agent submit job execute status'
  task job: :environment do
    if ENV['uuid'].to_s.empty?
      puts "Error: 请提供 Job UUID 作为参数"
      exit
    end

    job_json_path = agent_root_join("jobs/sypctl-job-#{ENV['uuid']}.json")
    job_command_path = agent_root_join("jobs/sypctl-job-#{ENV['uuid']}.sh")
    job_output_path = agent_root_join("jobs/sypctl-job-#{ENV['uuid']}.sh-output")

    job_hsh = JSON.parse(IO.read(job_json_path))
    job_hsh['state'] = 'done'
    job_hsh['output'] = File.exists?(job_output_path) ? IO.read(job_output_path) : "无输出"
    post_to_server_job(job_hsh)
  end

  desc 'print aget regisiter info'
  task info: :environment do
    print_agent_info
  end

  desc 'print agent submitor log'
  task log: :environment do
    print_agent_log
  end
end