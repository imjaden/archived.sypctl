# encoding: utf-8
require 'erb'
require 'lib/sinatra/extension_redis'
require 'active_support/core_ext/time'

namespace :redis do
  desc '生成 Redis 配置档 - config/redis.conf'
  task generate_config: :environment do
    config_path = %(#{ENV['APP_ROOT_PATH']}/config/redis.conf)
    template_path = config_path + '.erb'
    File.open(config_path, 'w:utf-8') do |file|
      file.puts ERB.new(File.read(template_path)).result
    end
  end

  desc 'Redis 登录信息同步至 MySQL，每小时整点执行'
  task login_2_mysql: :environment do
    register Sinatra::Redis

    two_hours_ago = Time.now.advance(hours: -1.5)
    redis.keys(%(*user/*/login)).each do |key|
      redis_hash = redis.hgetall(key)

      # 每小时执行，安全起见，以 1.5 小时为判断标准
      latest_login_at = redis_hash['latest_login_at'].to_time
      next unless latest_login_at > two_hours_ago

      user = User.find_by(id: redis_hash['user_id'])
      next unless user

      user.update_columns(
        last_login_at: redis_hash['latest_login_at'].to_time,
        last_login_ip: redis_hash['latest_login_ip'],
        last_login_browser: redis_hash['latest_login_browser'],
        last_login_version: redis_hash['version'],
        sign_in_count: redis_hash['count'].to_i
      )
    end
  end

  desc 'deprecated@login_stat => login'
  task deprecated_login_stat: :environment do
    register Sinatra::Redis

    redis.keys('*user_num/*/login_stat*').each do |deprecated_key_name|
      puts deprecated_key_name
      user_num = deprecated_key_name.scan(/user_num\/(.*?)\/login_stat/).flatten.first
      user = User.find_by(user_num: user_num)

      next unless user

      key_name = %(user/#{user.id}/login)
      current_login_count = redis.hget(deprecated_key_name, 'sign_in_count')
      redis.exists(key_name) ? redis.hincrby(key_name, 'count', current_login_count) : redis.hset(key_name, 'count', current_login_count)
      redis.hmset(key_name, [
        'user_name', user.user_name,
        'user_id', user.id,
        'version', redis.hget(deprecated_key_name, 'last_login_version'),
        'platform', '',
        'latest_login_at', redis.hget(deprecated_key_name, 'last_login_at'),
        'latest_login_ip', redis.hget(deprecated_key_name, 'last_login_ip'),
        'latest_login_browser', redis.hget(deprecated_key_name, 'last_login_browser')
      ])
    end
  end
end
