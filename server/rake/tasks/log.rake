# encoding: utf-8
require 'json'
require 'lib/sinatra/extension_redis'

namespace :log do
  namespace :redis_to_mysql do
    VISITED_LOGGER_PID = 'sync_redis_visited_logger'.freeze
    VISITED_REDIS_KEY  = 'redis_to_mysql/visit'.freeze
    ACTION_LOGGER_PID  = 'sync_redis_action_logger'.freeze
    ACTION_REDIS_KEY   = 'redis_to_mysql/action'.freeze

    task visit: :environment do
      register Sinatra::Redis
      begin
        exit_when_redis_not_match(VISITED_REDIS_KEY, 'status', 'running')

        generate_pid_file(VISITED_LOGGER_PID, Process.pid)
        update_redis_key_value(VISITED_REDIS_KEY, 'status', 'running')

        records = redis.smembers(::VisitLog.redis_key) || []
        records.each_slice(100) do |batch_records|
          ::VisitLog.create(batch_records.map { |json| JSON.parse(json) })
          redis.srem(::VisitLog.redis_key, batch_records)
        end

        update_redis_key_value(VISITED_REDIS_KEY, 'status', 'done')
      rescue => e
        puts "#{__FILE__}:#{__LINE__} - #{e.message}"
        puts e.backtrace.find_all { |info| info.include?(ENV['APP_ROOT_PATH']) }
        update_redis_key_value(VISITED_REDIS_KEY, 'status', 'crashed')
      ensure
        delete_pid_file(VISITED_LOGGER_PID)
      end
    end

    def action_record_log_to_mysql_guarder(json)
      hsh = JSON.parse(json) 
      hsh['obj_title'] = hsh['obj_title'].to_s[0..498]
      hsh['user_name'] = hsh['user_name'].to_s.scan(/\p{Han}+|\w|\s|-|_/u).join.gsub(/\s+/, ' ').strip[0..253]
      hsh
    rescue => e
      puts json
      puts "#{Time.now}: #{__FILE__}@#{__LINE__}\n#{e.message}"
      nil
    end

    task action: :environment do
      register Sinatra::Redis

      exit_when_redis_not_match(ACTION_REDIS_KEY, 'status', 'running')
      generate_pid_file(ACTION_LOGGER_PID, Process.pid)
      update_redis_key_value(ACTION_REDIS_KEY, 'status', 'running')
      begin
        records = redis.smembers(ActionLog.redis_key) || []
        records.each_slice(100) do |batch_records|
          time1 = Time.now
          begin
            valid_records = batch_records.map { |json| action_record_log_to_mysql_guarder(json) }.reject(&:nil?)
            ::ActionLog.create(valid_records)
            redis.srem(ActionLog.redis_key, batch_records)
            time2 = Time.now
          rescue => ie
            puts "#{Time.now}: #{__FILE__}@#{__LINE__}\n#{ie.message}\n后续操作：批量插入异常时逐行插入，确保正常数据同步至库"
            batch_records.each do |json| 
              begin
                next unless valid_record = action_record_log_to_mysql_guarder(json)
                ::ActionLog.create(valid_record)
                redis.srem(ActionLog.redis_key, json)
              rescue => iie
                puts "#{Time.now}: #{__FILE__}@#{__LINE__}\n#{iie.message}\n异常数据跳转，继续遍历数据同步至库"
              end
            end
            time2 = Time.now
          end
          puts "#{time2}, #{time2 - time1}"
        end

        update_redis_key_value(ACTION_REDIS_KEY, 'status', 'done')
      rescue => e
        puts "#{__FILE__}:#{__LINE__} - #{e.message}"
        puts e.backtrace.find_all { |info| info.include?(ENV['APP_ROOT_PATH']) }
        update_redis_key_value(ACTION_REDIS_KEY, 'status', 'crashed')
      ensure
        delete_pid_file(ACTION_LOGGER_PID)
      end
    end
  end
end
