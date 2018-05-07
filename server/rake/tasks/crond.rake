require 'active_record'
require 'fileutils'

namespace :crond do
  def exec_sql(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  desc 'every day 07:30 am'
  task day: :environment do
    exec_sql('call ETL_all;')
  end

  desc 'every 20 minutes'
  task minutes: :environment do
    exec_sql('call ETL_report_id_001_realtime;')
    exec_sql('update report_bases set load_time = now(),`updated_at` = now() where report_id = 1;')
  end
end
