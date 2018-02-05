# encoding: utf-8
require 'json'

desc '用户报表自动生成器'
namespace :statistic do
  def report_someday_data(date_str)
    day_records = ActionLog.find_by_sql <<-EOF
      select
        user_id,
        date_format(created_at, '%H:%i') as time,
        locate('Android', browser) as browser_type
      from sys_action_logs
      where date_format(created_at, '%y/%m/%d') = '#{date_str}';
    EOF
    count_ios = day_records.count { |r|  r.browser_type && r.browser_type.zero? }
    times = day_records.map(&:time).sort

    {
      date: date_str,
      count: day_records.count,
      count_ios: count_ios,
      count_android: day_records.count - count_ios,
      people: day_records.map(&:user_id).uniq.count,
      people_ios: day_records.select { |r| r.browser_type && r.browser_type.zero? }.map(&:user_id).uniq.count,
      people_android: day_records.select { |r| r.browser_type && !r.browser_type.zero? }.map(&:user_id).uniq.count,
      first: times.first,
      last: times.last
    }
  end

  def report_path
    File.join(ENV['APP_ROOT_PATH'], 'tmp/report_login_data.json')
  end

  def save_report(reports)
    if reports.nil?
      puts 'reports data is nil'
      return
    end

    File.open(report_path, 'w:utf-8') do |file|
      file.puts(reports.sort_by! { |a| a['date'] || a[:date] }.to_json)
    end
  end

  def report_someday(nday)
    someday_str = (Time.now - nday * 24 * 60 * 60).strftime('%y/%m/%d')
    someday_report_data = report_someday_data(someday_str)

    reports = read_json_guard(report_path, [])
    reports = reports.reject { |h| h['date'] == someday_str }
    reports.push(someday_report_data)
    puts someday_report_data

    save_report(reports)
  end

  def read_json_guard(json_path, default_return = [])
    return default_return unless File.exist?(json_path)

    json_hash = JSON.parse(IO.read(json_path))
    return default_return unless json_hash.is_a?(Array)
    json_hash
  rescue
    File.delete(json_path) if File.exist?(json_path)
    default_return
  end

  namespace :login do

    desc 'test'
    task :test do
      puts app_root_join('tmp/report_login_data.json')
    end

    desc '登录日期去重，生成报表'
    task all: :environment do
      login_dates = ActionLog.find_by_sql(%(select distinct date_format(created_at, '%y/%m/%d') as login_date from sys_action_logs))
      report_data = login_dates.map do |record|
        report_someday_data(record.login_date)
      end

      save_report(report_data)
    end

    desc '更新昨日数据'
    task yesterday: :environment do
      report_someday(1)
    end

    desc '更新今日数据'
    task today: :environment do
      report_someday(0)
    end
  end
end
