# encoding: utf-8
require 'uri'
require 'json'
require 'settingslogic'
require 'active_support'
require 'active_support/core_ext/hash'
require 'active_support/core_ext/string'
require 'lib/utils/template_v1_engine'
require 'lib/utils/template_v2_engine'
require 'lib/utils/template_v3_engine'
require 'lib/utils/template_v4_engine'
require 'lib/utils/template_v5_engine'
require 'lib/utils/template_class_methods'
require 'lib/utils/template_instance_methods'
require 'lib/utils/template_engine_checker'
require 'lib/utils/mail_sender'
require 'lib/sinatra/extension_redis'
require 'lib/utils/sms_sender'

namespace :debug do
  task audio: :environment do
    Report.where(has_audio: true).each do |report|
      puts report.refresh_audio_cache(165)
      puts report.audio_cache_path(165)
    end
  end

  task single_value: :environment do

    group_id = 165
    report = Report.find_by(report_id: 27)
    report.update(content: File.read('s'))
    javascript_path = report.file_cache_path(group_id, false)
    engine = %(::Template::V#{report.template_id}::Engine).camelize.constantize
    engine.new.parse(group_id, report, javascript_path, Time.now, true)

    `subl #{javascript_path}`
  end

  namespace :redis do
    task report: :environment do
      register Sinatra::Redis

      redis_format_key = 'cache/report/%s'.freeze
      KpiBase.all.each do |kpi|
        next if kpi.link.blank?

        redis_key = format(redis_format_key, kpi.link)
        next unless redis.exists(redis_key)

        redis_hash = redis.hgetall(redis_key)
        exception = redis_hash.fetch('exception', nil)
        next unless exception

        puts format('%s, id:%s, title:%s, exception: %s,', redis_hash.fetch('updated_at', ''), redis_hash.fetch('id', ''), redis_hash.fetch('title', ''), redis_hash.fetch('exception', ''))
      end
    end

  end

  def report_tables(report)
    report_options = JSON.parse(report.content)

    if report.template_id.to_i == 3
      report_options = report_options.deep_symbolize_keys
    else
      report_options = report_options.map { |report_option| report_option.deep_symbolize_keys }
    end

    checker = Template::Engine::Checker.new
    tables = checker.send(%(extract_v#{report.template_id}_table_name), report_options).flatten.uniq
    # format('%s; %s; %s; %s;', report.report_id, report.template_id, report.title, tables.count)
  end

  task sql: :environment do
    tables = []
    Report.where('report_id in (9,58,43,46,45,35,8,11,10,60,31,62,34,21,999,61,36,27,54,19,52,30,24,2,37,1,3,4,55,6,7,0,17,26,5,57,25,53,20,22,18,29,41,9903,38,42,33,12,28,40,56,9902,9909,47,14,9904,9908,9901,48)').each do |report|
      tables << report_tables(report)
    end

    puts tables.flatten.uniq.join(' ')
  end

  task clean: :environment do
    con = ActiveRecord::Base.connection
    tables = con.data_sources
    bak_tables = tables.select { |tn| tn.include?('bak') }
    puts "bak tables: #{bak_tables}"

    report_ids = Report.pluck(:report_id)
    delete_tables = tables.select { |tn| tn.start_with?('report_data') }
      .select { |tn|
        if tn =~ /report_data_(\d+)_*/
          !report_ids.include?($1.to_i)
        end
      }
    puts "delete_tables: #{delete_tables}"
    (bak_tables + delete_tables).each do |tn|
      con.drop_table(tn)
    end
  end

  namespace :benchmark do
    require 'benchmark'

    task pluck: :environment do
      def massive_run(&block)
        10.times { yield }
      end

      Benchmark.bm(7) do |x|
        x.report('map') do
          massive_run { GroupReport.select('distinct report_id').map(&:report_id) }
        end

        x.report('pluck') do
          massive_run { GroupReport.pluck('distinct report_id') }
        end
      end
    end

    task rand: :environment do
      def massive_run(&block)
        1.upto(10) { yield }
      end

      Benchmark.bm(7) do |x|
        x.report('server') do
          massive_run { User.all.sample }
        end
        x.report('sql') do
          massive_run { User.all.order('rand()').limit(1).first }
        end
      end
    end

    task pluck2: :environment do
      def massive_run(&block)
        10.times { yield }
      end

      Benchmark.bm(7) do |x|
        @kpi_datas = KpiBase.find(8).kpi_datas.where(group_id: 165).order(num: :asc).limit(10)

        x.report(:pluck) do
          massive_run { @kpi_datas.pluck(:value1) }
        end

        x.report(:map) do
          massive_run { @kpi_datas.map(&:value1) }
        end
      end
    end
  end
end
