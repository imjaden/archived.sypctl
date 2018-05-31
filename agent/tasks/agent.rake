# encoding: utf-8
require 'json'
require 'securerandom'

namespace :agent do
  desc "agent submit self info every 1 minutes"
  task submitor: :environment do
    post_to_server_register unless File.exists?(agent_json_path)
    agent_json_hash = JSON.parse(IO.read(agent_json_path))
    post_to_server_register unless agent_json_hash["synced"]

    post_to_server_submitor
  end

  desc 'agent submit job execute status'
  tas job: :environment do
    if ENV['uuid'].to_s.empty?
      puts "请提供 Job UUID 作为参数"
      exit
    end

    job_json_path = agent_root_join("tmp/sypctl-job-#{ENV['uuid']}.json")
    job_command_path = agent_root_join("tmp/sypctl-job-#{ENV['uuid']}.sh")
    job_output_path = agent_root_join("tmp/sypctl-job-#{ENV['uuid']}-output")


    job_hsh = JSON.parse(IO.read(job_json_path))
    job_hsh['state'] = 'done'
    job_hsh['output'] = File.exists?(job_output_path) ? IO.read(job_output_path) : "无输出"
    post_to_server_job(job_hsh)
  end
end