# encoding: utf-8
require 'zip'
require 'json'
require 'active_support'
require 'active_support/time'
require 'active_support/core_ext/string'
require 'lib/sinatra/extension_redis'

namespace :barcode do
  BARCODE_TASK_PID     = 'barcode_cache_task'.freeze
  BARCODE_RECORD_LIMIT = 1_0000.freeze
  BARCODE_TASK_KEY     = 'cache/barcode/task'.freeze
  BARCODE_OFFSET_KEY   = 'cache/barcode/offset/%s'.freeze

  def barcode_task_logger
    @barcode_logger || -> {
      log_path = File.join(ENV['APP_ROOT_PATH'], 'log', 'barcode_time_consuming.log')
      @barcode_logger = Logger.new(log_path)
      @barcode_logger.formatter = proc do |severity, datetime, progname, msg|
        "#{datetime.strftime('%Y-%m-%d %H:%M:%S')}; #{msg}\n"
      end
      @barcode_logger
    }.call
  end

  # redis cache info structure
  #
  # offset_number = offset * BARCODE_RECORD_LIMIT
  # cache/barocde/offset/:offset {
  #   status: running/done/crash/retry
  #   time_start:
  #   time_end:
  #   time_run:
  #   updated_at: barcodes updated_at
  #   updated_ats: latest 2**7 updated_ats history
  #   exception:
  # }
  #
  def update_barcode_redis_status(redis_key, status, updated_at = nil, exception = 'null')
    if status == 'running'
      redis.hmset(redis_key, [
        'status', status,
        'time_start', Time.now.to_i,
        'time_end', '',
        'time_run', '',
        'updated_at', status,
        'exception', ''
      ])
      refresh_redis_key_value(redis_key, 'updated_ats', updated_at || 'null')
    elsif status == 'done'
      redis.hmset(redis_key, [
        'status', status,
        'time_end', Time.now.to_i,
        'updated_at', updated_at || 'null'
      ])
      update_redis_run_time(redis_key)
    elsif status == 'crash'
      redis.hmset(redis_key, [
        'status', status,
        'time_end', Time.now.to_i,
        'exception', exception,
        'updated_at', Time.now
      ])
      update_redis_run_time(redis_key)
    end
  end

  # cache/barcode/task {
  #   status: execute status
  #   time_start: start execute time
  #   time_end: finished execute time
  #   time_run: execute duration time
  #   bookmark: current amount period # count
  #   updated_at: maximum(updated_at)
  #   updated_ats: latest 2**5 updated_ats history
  #   exception: exception.message
  # }
  #
  def update_barcode_task_redis_status(status, updated_at)
    if status == 'running'
      redis.hmset(BARCODE_TASK_KEY, [
        'status', status,
        'time_start', Time.now.to_i,
        'time_end', '',
        'time_run', '',
        'bookmark', '',
        'updated_at', status,
        'exception', ''
      ])
      refresh_redis_key_value(BARCODE_TASK_KEY, 'updated_ats', updated_at || 'null')
    elsif status == 'done'
      redis.hmset(BARCODE_TASK_KEY, [
        'status', status,
        'time_end', Time.now.to_i,
        'updated_at', updated_at
      ])
      update_redis_run_time(BARCODE_TASK_KEY)
    end
  end

  namespace :cache do
    desc 'display task detail status'
    task report: :environment do
      temp_path = tmp_pid_path(BARCODE_TASK_PID)
      puts %(#{temp_path}(#{File.read(temp_path)})) if File.exist?(temp_path)

      register Sinatra::Redis
      redis_hash = redis.hgetall(BARCODE_TASK_KEY)
      puts format('    status: %s', redis_hash.fetch('status', 'null'))
      puts format('updated_at: %s', redis_hash.fetch('updated_at', 'null'))
      puts format('  bookmark: %s', redis_hash.fetch('bookmark', 'null'))
      puts format('     start: %s', Time.at(redis_hash.fetch('time_start', 0).to_i))
      puts format('       end: %s', Time.at(redis_hash.fetch('time_end', 0).to_i))
      puts format('       run: %s', redis_hash.fetch('time_run', 'null'))
      puts format(' exception: %s', redis_hash.fetch('exception', 'null'))
      puts '  offset/*:'
      puts `redis-cli keys '*cache/barcode/offset/*' | xargs -I key redis-cli hget key updated_at | uniq`
    end

    desc 'generate barcode api format file cache'
    task :refresh do
      begin
        task_command = 'barcode:cache:_refresh'
        Rake::Task[task_command].invoke
      rescue => exception
        include ::Mail::Methods
        send_rake_crashed_email(exception, task_command, __FILE__, __LINE__)
      ensure
        delete_pid_file(BARCODE_TASK_PID)
      end
    end

    desc 'generate barcode api format file cache'
    task _refresh: :environment do
      register Sinatra::Redis

      exit_when_redis_not_match(BARCODE_TASK_KEY, 'status', 'running')
      current_timestamp = BarcodeResult.maximum(:updated_at).to_s
      exit_when_redis_not_match(BARCODE_TASK_KEY, 'updated_at', current_timestamp)

      start_time = Time.now
      update_barcode_task_redis_status('running', current_timestamp)
      generate_pid_file(BARCODE_TASK_PID, Process.pid)
      barcode_task_logger.info(format('start; %s; %s; -; -', Process.pid, current_timestamp))

      BarcodeResult.clear_area_cache
      BarcodeResult.update_area_store_num
      BarcodeResult.make_sure_store_cache_path_exist

      records_count = BarcodeResult.count
      exit_when(records_count.zero?, 'barcode is empty')

      threads = []
      limit = (BarcodeResult.count/BARCODE_RECORD_LIMIT).to_i + 1
      (0..limit).each_with_index do |offset, thread_index|
        threads << Thread.new(offset, thread_index) do |offset, thread_index|
          inner_start_time = Time.now
          offset_number = offset * BARCODE_RECORD_LIMIT

          update_redis_key_value(BARCODE_TASK_KEY, 'bookmark', offset_number)
          barcodes = BarcodeResult.order(id: :desc).limit(BARCODE_RECORD_LIMIT).offset(offset_number)
          Thread.current.exit if barcodes.empty?

          updated_at = barcodes.max_by(&:updated_at).updated_at.to_s
          redis_offset_key = format(BARCODE_OFFSET_KEY, offset_number)
          Thread.current.exit if redis.exists(redis_offset_key) && redis.hget(redis_offset_key, 'updated_at') == updated_at

          update_barcode_redis_status(redis_offset_key, 'running', updated_at)
          whether_consider_perfermance = !BarcodeResult.staisfy_generate_area_data_condition?
          barcodes.each { |record| record.refresh_file_cache(whether_consider_perfermance) }
          update_barcode_redis_status(redis_offset_key, 'done', updated_at)

          barcode_task_logger.info(format('%s; %s; %s; %.2fs', current_timestamp, offset_number, updated_at, Time.now - inner_start_time))
        end

        threads.each(&:join) if threads.count == Setting.thread_limit.barcode
        threads.keep_if(&:status)
      end
      threads.each(&:join) unless threads.empty?

      update_barcode_task_redis_status('done', current_timestamp)
      info = format('done; %s; %s; %s; %.2fs', Process.pid, current_timestamp, start_time, Time.now - start_time)
      barcode_task_logger.info(info); puts info
    end
  end

  # deprecated idea
  def generate_barcode_zip(barcode_path)
    barcode_zip_path = barcode_path.sub('tmp/barcode', 'tmp/barcode.zip') + '.zip'
    File.delete(barcode_zip_path) if File.exist?(barcode_zip_path)

    Zip::File.open(barcode_zip_path, Zip::File::CREATE) do |zipfile|
      zipfile.add(File.basename(barcode_path), barcode_path)
    end
  rescue => e
    File.delete(barcode_zip_path) if File.exist?(barcode_zip_path)
    File.open(barcode_zip_path + '.error', 'w:utf-8') do |file|
      file.puts <<-EOF.strip_heredoc
        timestamp: '#{Time.now}'
        javascript_zip_path: #{javascript_zip_path}
        message: #{e.message}
        backtrace: \n
        #{e.backtrace.join('\n')}
      EOF
    end
  end
end
