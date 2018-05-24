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
end