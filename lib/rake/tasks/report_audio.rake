# encoding: utf-8
require 'uri'
require 'logger'
require 'settingslogic'
require 'securerandom'
require 'active_support/core_ext/string'
require 'lib/utils/template_v1_engine'
require 'lib/utils/template_v2_engine'
require 'lib/utils/template_v3_engine'
require 'lib/utils/template_v4_engine'
require 'lib/utils/template_v5_engine'
require 'lib/utils/template_v10_engine'
require 'lib/utils/template_instance_methods'
require 'lib/utils/mail_sender'
require 'lib/sinatra/extension_redis'

namespace :report do
  REPORT_AUDIO_CACHE_PID        = 'report_cache_audio'.freeze
  REPORT_AUDIO_FORMAT_REDIS_KEY = 'cache/report/%s/audio'.freeze
  REPORT_AUDIO_REDIS_KEY        = 'cache/report/audio'.freeze

  namespace :cache do
    def updated_audio_report_ids(report_ids, redis_format_key)
      new_report_ids = []
      report_ids.each do |report_id|
        if record = ::TimestampManager.find_by(obj_type: 'report#audio', obj_id: report_id)
          redis_cache_key = format(redis_format_key, report_id)
          next if redis.exists(redis_cache_key) && redis.hget(redis_cache_key, 'updated_at') == record.timestamp.to_s
          new_report_ids.push(report_id)
        else
          new_report_ids.push(report_id)
        end
      end
      new_report_ids
    end

    desc 'refresh reports audio'
    task audio: :environment do
      register Sinatra::Redis
      include ::Template::InstanceMethods

      refresh_type     = 'audio'
      task_pid_file    = REPORT_AUDIO_CACHE_PID
      redis_status_key = REPORT_AUDIO_REDIS_KEY
      redis_format_key = REPORT_AUDIO_FORMAT_REDIS_KEY

      exit_when_redis_not_match(redis_status_key, 'status', 'running')

      report_ids = Report.all.map(&:report_id)
      current_timestamp = report_ids.empty? ? 'null' : ::TimestampManager.report_audio_timestamp(report_ids).to_s
      update_redis_key_value(redis_status_key, 'database_timestamp', current_timestamp)

      exit_when_redis_not_match(redis_status_key, 'updated_at', current_timestamp)

      start_time = Time.now
      generate_pid_file(task_pid_file, Process.pid)
      update_report_task_redis_status(redis_status_key, 'running', current_timestamp, refresh_type)

      report_ids = updated_audio_report_ids(report_ids, redis_format_key)
      update_redis_key_value(redis_status_key, 'report_id', report_ids.join(','))
      refresh_redis_key_value(redis_status_key, 'report_ids', report_ids.join(','))
      report_task_logger(refresh_type).info(format('start; %s; %s; %s; -; %s', Process.pid, refresh_type, current_timestamp, report_ids.join(',')))

      threads = []
      report_ids.each_with_index do |report_id, index|
        begin
          next unless report = Report.find_by(report_id: report_id)
          next unless report.has_audio

          inner_start_time = Time.now
          audio_updated_at = ::TimestampManager.report_audio_timestamp(report_id).to_s
          update_report_redis_status(redis_format_key, 'running', report_id, audio_updated_at)

          group_ids = [0]
          group_ids = report.group_ids if report.template_id != 4
          group_ids.each do |group_id|
            runtime_block report.audio_cache_path(group_id) do
              report.refresh_audio_cache(group_id, audio_updated_at)
            end
          end
          update_report_redis_status(redis_format_key, 'done', report_id, audio_updated_at)
          report_task_logger.info(format('%s; %s; %s; %s; %.2fs', current_timestamp, report_id, group_ids.count, audio_updated_at, Time.now - inner_start_time))
        rescue => e # ActiveRecord::ConnectionTimeoutError => e
          puts e.message
          update_report_redis_status(redis_format_key, 'crash', report_id, nil, e.message)
        end
      end

      delete_pid_file(task_pid_file)
      update_report_task_redis_status(redis_status_key, 'done', current_timestamp, refresh_type)
      info = format('done; %s; %s; %s; %ss; %s', Process.pid, refresh_type, current_timestamp, Time.now - start_time, report_ids.join(','))
      report_task_logger.info(info); puts info
    end
  end
end
