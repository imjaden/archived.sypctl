# encoding: utf-8
require 'fileutils'
require 'securerandom'
require 'lib/sinatra/extension_redis'

namespace :user do
  task copy_deprecated_gravatar: :environment do
    UserGravatar.find_each(batch_size: 1000) do |ug|
      gravatar_path = File.join(ENV['APP_ROOT_PATH'], 'public/images', ug.filename)
      next if File.exist?(gravatar_path)

      filename = "gravatar-#{SecureRandom.uuid.gsub('-', '')}#{File.extname(ug.filename)}"
      gravatar_path = File.join(ENV['APP_ROOT_PATH'], 'public/images', filename)
      deprecated_gravatar_path = File.join(ENV['APP_ROOT_PATH'], 'public/gravatar', ug.filename)
      next unless File.exist?(deprecated_gravatar_path)

      FileUtils.cp(deprecated_gravatar_path, gravatar_path)
      ug.update_attributes(filename: filename, is_upload_cdn: false)
    end
  end

  desc 'update store ids'
  task update_store_ids: :environment do
    User.find_each(batch_size: 1000) do |user|
      user.update_columns(store_ids: user.store_ids_string)
    end
  end

  desc 'sync mysql data to redis without logined info'
  task sync_simple_to_redis: :environment do
    register Sinatra::Redis

    User.find_each(batch_size: 1000) do |user|
      user_redis_key = User.user_redis_key(user.user_num)
      redis.hmset(user_redis_key, user.to_redis)
    end

    Rake::Task['user:caculate_from_redis'].invoke
  end

  desc 'sync mysql data to redis with logined info'
  task sync_to_redis: :environment do
    register Sinatra::Redis

    User.find_each(batch_size: 1000) do |user|
      user_redis_key = User.user_redis_key(user.user_num)
      redis.hmset(user_redis_key, user.to_redis)
    end

    Rake::Task['user:init_caculate_to_redis'].invoke
  end

  task hscan: :environment do
    register Sinatra::Redis

    statistic_redis_key = User.statistic_redis_key
    puts redis.hgetall(statistic_redis_key).to_json
  end

  desc 'caculate login/browse report staticstic to redis'
  task caculate_from_redis: :environment do
    register Sinatra::Redis

    statistic_redis_key = User.statistic_redis_key
    max_login_count  = (redis.hget(statistic_redis_key, "max_login_count") || 100).to_i
    min_login_count  = (redis.hget(statistic_redis_key, "min_login_count") || 0).to_i
    max_report_count = (redis.hget(statistic_redis_key, "max_report_count") || 100).to_i
    min_report_count = (redis.hget(statistic_redis_key, "min_report_count") || 0).to_i

    login_values = redis.hscan(statistic_redis_key, 0, {match: '*/login_count', count: 100_000_000})[1].map(&:last).map(&:to_i)
    report_values = redis.hscan(statistic_redis_key, 0, {match: '*/report_count', count: 100_000_000})[1].map(&:last).map(&:to_i)

    max_login_count = login_values.max || max_login_count
    min_login_count = login_values.min || min_login_count
    max_report_count = report_values.max || max_report_count
    min_report_count = report_values.min || min_report_count

    redis.hmset(statistic_redis_key, [
      "max_login_count", max_login_count,
      "min_login_count", min_login_count,
      "max_report_count", max_report_count,
      "min_report_count", min_report_count
    ])

    redis.hscan(statistic_redis_key, 0, {match: "*/login_count", count: 100_000_000})[1].map(&:first).uniq.each do |login_count_str|
      user_num         = login_count_str.sub('/login_count', '')
      login_day_str    = login_count_str.sub('/login_count', '/login_day')
      report_count_str = login_count_str.sub('/login_count', '/report_count')
      updated_date_str = login_count_str.sub('/login_count', '/updated_date_str')
      next if user_num.empty?
      puts user_num
      puts login_day_str
      puts report_count_str
      puts updated_date_str
      login_count  = (redis.hget(statistic_redis_key, login_count_str) || 0).to_i
      login_day    = (redis.hget(statistic_redis_key, login_day_str) || 0).to_i
      report_count = (redis.hget(statistic_redis_key, report_count_str) || 0).to_i
      updated_date = (redis.hget(statistic_redis_key, updated_date_str) || Time.now).to_i

      cal1 = 1.0*(login_count - min_login_count)/(max_login_count - min_login_count)*50
      cal2 = 1.0*(report_count - min_report_count)/(max_report_count - min_report_count)*50
      cal3 = (cal1 + cal2).round(1)
      redis.hmset(statistic_redis_key, [
        "#{user_num}/updated_date_str", Time.now.to_i, 
        "#{user_num}/login_day", login_day + (Time.now.to_i - updated_date)/60/24, 
        "#{user_num}/login_count", login_count, 
        "#{user_num}/report_count", report_count, 
        "#{user_num}/login_duration", login_day, 
        "#{user_num}/browse_report_count", report_count, 
        "#{user_num}/surpass_percentage", (cal3 >= 100 ? 99.9 : cal3)
      ])
    end
  end

  desc 'caculate login/browse report staticstic to redis'
  task init_caculate_to_redis: :environment do
    register Sinatra::Redis
    conn = ActiveRecord::Base.connection

    sql_strings=<<-SQL
      DROP TABLE IF EXISTS `tmp_cal_action_logs`;
      CREATE TABLE `tmp_cal_action_logs` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `action` varchar(255) DEFAULT NULL,
        `user_num` varchar(255) DEFAULT NULL,
        `created_at` datetime DEFAULT NULL,
        PRIMARY KEY (`id`)
      ) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;
      INSERT INTO tmp_cal_action_logs (action, user_num, created_at) 
      SELECT action, user_num, created_at
      FROM sys_action_logs
      WHERE
        user_num IS NOT NULL
      AND LENGTH(user_num) > 0
      AND action IN (
        '登录',
        '点击/报表/报表',
        '点击/专题/报表',
        '点击/生意概况/报表',
        '点击/工具箱/报表',
        '点击/设备/报表'
      )
    SQL
    sql_strings.split(";").each { |sql_string| conn.execute(sql_string) }

    sql_string = <<-SQL
     select max(login_count) as count1, min(login_count) as count2, max(report_count) as count3, min(report_count) as count4
     from (
         select user_num,
            count(case when action = '登录' then id end) as login_count,
            count(case action
                  when '点击/工具箱/报表' then id
                  when '点击/设备/报表' then id
                  when '点击/专题/报表' then id
                  when '点击/生意概况/报表' then id
                  when '点击/报表/报表' then id end) as report_count
           from tmp_cal_action_logs
          group by user_num
     ) as a
    SQL

    max_login_count, min_login_count, max_report_count, min_report_count = conn.execute(sql_string).to_a.flatten
    max_report_count ||= 1
    min_report_count ||= 0
    max_login_count ||= 1
    min_login_count ||= 0

    statistic_redis_key = User.statistic_redis_key
    redis.hmset(statistic_redis_key, [
      "max_login_count", max_login_count,
      "min_login_count", min_login_count,
      "max_report_count", max_report_count,
      "min_report_count", min_report_count
    ])

    sql_string = <<-SQL
      select sal.user_num,
        count(distinct date_format(sal.created_at, '%Y-%m-%d')) as login_day,
        count(case sal.action when '登录' then sal.id end) as login_count,
        count(case sal.action
              when '点击/工具箱/报表' then sal.id
              when '点击/设备/报表' then sal.id
              when '点击/专题/报表' then sal.id
              when '点击/生意概况/报表' then sal.id
              when '点击/报表/报表' then sal.id end) as report_count
      from tmp_cal_action_logs as sal
      where sal.user_num is not null
      group by sal.user_num
      order by login_count desc, report_count desc
    SQL

    conn.execute(sql_string).each do |array|
      user_num, login_day, login_count, report_count = array

      cal1 = 1.0*(login_count - min_login_count)/(max_login_count - min_login_count)*50
      cal2 = 1.0*(report_count - min_report_count)/(max_report_count - min_report_count)*50
      cal3 = (cal1 + cal2).round(1)
      redis.hmset(statistic_redis_key, [
        "#{user_num}/updated_date_str", Time.now.to_i, 
        "#{user_num}/login_day", login_day, 
        "#{user_num}/login_count", login_count, 
        "#{user_num}/report_count", report_count, 
        "#{user_num}/login_duration", login_day, 
        "#{user_num}/browse_report_count", report_count, 
        "#{user_num}/surpass_percentage", (cal3 >= 100 ? 99.9 : cal3)
      ])
    end
  end
end
