# encoding: utf-8
require 'fileutils'

namespace :saas do
  namespace :snapshot do
    SAAS_SNAPSHOT_FISHNET_REPORT_PID       = 'saas_snapshot_fishnet'.freeze
    SAAS_SNAPSHOT_FISHNET_REPORT_REDIS_KEY = 'saas_snapshot_fishnet'.freeze

    task fishnet: :environment do
      register Sinatra::Redis

      exit_when_redis_not_match(SAAS_SNAPSHOT_FISHNET_REPORT_REDIS_KEY, 'status', 'running')
      update_redis_key_value(SAAS_SNAPSHOT_FISHNET_REPORT_REDIS_KEY, 'status', 'running')
      generate_pid_file(SAAS_SNAPSHOT_FISHNET_REPORT_PID, Process.pid)

      Dir.glob(app_tmp_join('snapshot-fishnet/*.*')) do |path|
        database, suffix = File.basename(path).to_s.split(".")
        snapshot_ids = IO.readlines(path).map(&:strip).uniq.compact.reject(&:empty?)

        snapshot_ids.each do |snapshot_id|
          bundle_command = "bundle exec rake snapshot:generate DATABASE=#{database} SNAPSHOT_ID=#{snapshot_id} >> log/crontab/snapshot_fishnet_#{database}.log 2>&1"
          puts bundle_command
          `#{bundle_command}`
        end
        FileUtils.rm_f(path)
      end
        
      update_redis_key_value(SAAS_SNAPSHOT_FISHNET_REPORT_REDIS_KEY, 'status', 'done')
      delete_pid_file(SAAS_SNAPSHOT_FISHNET_REPORT_PID)
    end

    task generate: :environment do
      unless record = ConferenceReportSnapshot.find_by(id: ENV['SNAPSHOT_ID'])
        puts "FAIL: 会议报表快照（id=#{ENV['CONFERENCE_ID']}) 查询失败"
        exit
      end

      record.generate_snapshot_cache
    end
  end
end