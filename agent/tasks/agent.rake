# encoding: utf-8
require 'json'

namespace :agent do
  def agent_json_path; "db/agent.json"; end
  def system_json_path; "db/system-#{Time.now.strftime('%y%m%d')}.json"; end

  def post_agent_to_server

  end

  desc "agent submit self info every 1 minutes"
  task submitor: :environment do
    post_agent_to_server unless File.exists?(agent_json_path)
    agent_json_hash = JSON.parse(IO.read(agent_json_path))
    post_agent_to_server unless agent_json_hash["synced"]

    
  end
end