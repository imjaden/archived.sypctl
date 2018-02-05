# encoding: utf-8
require 'lib/sinatra/extension_redis'

namespace :mobile do
  MOBILE_V2_REFRESH_PID = 'mobile_v2_refresh'.freeze
  MOBILE_V2_REDIS_KEY   = 'cache/mobile/v2'.freeze

  def mobile_v2_view_mtime(filename)
    temp_path = app_root_join(%(app/views/mobile/v2/#{filename}))
    File.mtime(temp_path)
  rescue => e
    puts e.message
    nil
  end

  def object_ids(role_id, object_type)
    ::RoleResource.where(role_id: role_id, obj_type: object_type).pluck('distinct obj_id')
  end

  def drop_page_cache_when_expired(redis_key, updated_at, cache_page_key, page_name)
    timestamp = mobile_v2_view_mtime(page_name)
    timestamp = updated_at if updated_at && updated_at > timestamp
    timestamp = timestamp.to_s

    return if redis.exists(redis_key) && redis.hget(redis_key, 'updated_at') == timestamp

    redis_keys = redis.keys(cache_page_key)
    unless redis_keys.empty?
      puts cache_page_key
      redis.del(redis_keys)
    end

    redis.hmset(redis_key, [
      'updated_at', timestamp,
      'time_at', Time.now.to_i
    ]);
  end

  namespace :v2 do
    desc 'refresh mobile#v2 redis cache'
    task refresh: :environment do
      register Sinatra::Redis

      exit_when_redis_not_match(MOBILE_V2_REDIS_KEY, 'status', 'running')

      update_redis_key_value(MOBILE_V2_REDIS_KEY, 'status', 'running')
      update_redis_key_value(MOBILE_V2_REDIS_KEY, 'time_start', Time.now.to_i)
      generate_pid_file(MOBILE_V2_REFRESH_PID, Process.pid)

      refresh_mobile_v2_kpi_cache
      refresh_mobile_v2_app_cache
      refresh_mobile_v2_analyse_cache
      refresh_mobile_v2_thursday_say_cache

      delete_pid_file(MOBILE_V2_REFRESH_PID)
      update_redis_key_value(MOBILE_V2_REDIS_KEY, 'status', 'done')
      update_redis_run_time(MOBILE_V2_REDIS_KEY)
    end

    def refresh_mobile_v2_kpi_cache
      runtime_block %(refresh mobile#v2 kpi) do
        redis_key = %(cache/mobile/v2/kpi)
        current_timestamp = TimestampManager.where(obj_type: 'kpi').maximum(:timestamp).to_s

        unless return_when_redis_not_match(redis_key, 'updated_at', current_timestamp)
          role_ids = redis.keys('/mobile/v2/*/role/*/kpi*').map do |redis_key|
            redis_key.scan(/\/role\/(.*?)\/kpi@/).flatten.first
          end.uniq
          puts format('kpi: %s', role_ids.join(','))
          role_ids.each do |role_id|
            updated_at = TimestampManager.select('max(timestamp) as timestamp')
                        .where(obj_id: object_ids(role_id, OBJ_TYPE_KPI), obj_type: 'kpi')
                        .first.timestamp
            cache_page_key = %(/mobile/v2/*/role/#{role_id}/kpi*)
            temp_redis_key = format('%s/role/%s', redis_key, role_id)
            drop_page_cache_when_expired(temp_redis_key, updated_at, cache_page_key, 'kpi.haml')
          end
        end

        redis.hmset(redis_key, [
          'updated_at', current_timestamp,
          'time_at', Time.now.to_s
        ])
      end
    end

    def refresh_mobile_v2_app_cache
      runtime_block %(refresh mobile#v2 app) do
        redis_key = %(cache/mobile/v2/app)
        current_timestamp = App.maximum(:updated_at).to_s

        unless return_when_redis_not_match(redis_key, 'updated_at', current_timestamp)
          role_ids = redis.keys('/mobile/v2/role/*/app*').map do |redis_key|
            redis_key.scan(/\/role\/(.*?)\/app@/).flatten.first
          end.uniq
          puts format('app: %s', role_ids.join(','))
          role_ids.each do |role_id|
            updated_at = App.select('max(updated_at) as timestamp')
                        .where(group_id: object_ids(role_id, OBJ_TYPE_APP))
                        .first.timestamp
            cache_page_key = %(/mobile/v2/role/#{role_id}/app*)
            temp_redis_key = format('%s/role/%s', redis_key, role_id)
            drop_page_cache_when_expired(temp_redis_key, updated_at, cache_page_key, 'app.haml')
          end
        end

        redis.hmset(redis_key, [
          'updated_at', current_timestamp,
          'time_at', Time.now.to_s
        ])
      end
    end

    def refresh_mobile_v2_analyse_cache
      runtime_block %(refresh mobile#v2 analyse) do
        redis_key = %(cache/mobile/v2/analyse)
        current_timestamp = Analyse.maximum(:updated_at).to_s

        unless return_when_redis_not_match(redis_key, 'updated_at', current_timestamp)
          role_ids = redis.keys('/mobile/v2/role/*/analyse*').map do |redis_key|
            redis_key.scan(/\/role\/(.*?)\/analyse@/).flatten.first
          end.uniq
          puts format('analyse: %s', role_ids.join(','))
          role_ids.each do |role_id|
            updated_at = Analyse.select('max(updated_at) as timestamp')
                        .where(group_id: object_ids(role_id, OBJ_TYPE_ANALYSE))
                        .first.timestamp
            cache_page_key = %(/mobile/v2/role/#{role_id}/analyse*)
            temp_redis_key = format('%s/role/%s', redis_key, role_id)
            drop_page_cache_when_expired(temp_redis_key, updated_at, cache_page_key, 'analyse.haml')
          end
        end

        redis.hmset(redis_key, [
          'updated_at', current_timestamp,
          'time_at', Time.now.to_s
        ])
      end
    end

    def refresh_mobile_v2_thursday_say_cache
      runtime_block %(refresh mobile#v2 thursday) do
        redis_key = %(cache/mobile/v2/thursday_say)
        current_timestamp = ThursdaySay.maximum(:updated_at).to_s

        unless return_when_redis_not_match(redis_key, 'updated_at', current_timestamp)
          cache_page_key = '/mobile/v2/thursday_say*'
          redis_keys = redis.keys(cache_page_key)
          redis.del(redis_keys) unless redis_keys.empty?
        end

        redis.hmset(redis_key, [
          'updated_at', current_timestamp,
          'time_at', Time.now.to_s
        ])
      end
    end
  end
end
