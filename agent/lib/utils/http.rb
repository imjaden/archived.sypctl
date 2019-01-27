# encoding: utf-8
require 'json'
require 'rest-client'
require 'securerandom'

module Sypctl
  class Http
    class << self
      def default_header
        {'User-Agent' => "sypctl #{ENV['SYPCTL_VERSION']};#{ENV['RUBY_VERSION']}"} # 'Content-Type' => 'application/json', 
      end

      def post(url, playload = {}, headers = {}, external_options = {print_log: false})
        response = RestClient.post(url, playload, default_header.merge(headers))
        if external_options[:print_log]
          puts "post #{url}"
          puts "parameters: \n#{JSON.pretty_generate(playload)}"
          puts "response code: #{response.code}"
          puts "response body: \n#{JSON.pretty_generate(JSON.parse(response.body))}"
        end
        {'code' => response.code, 'body' => response.body, 'hash' => JSON.parse(response.body)}
      rescue => e
        puts "#{__FILE__}@#{__LINE__}: #{e.message}"
        {'code' => 500, 'body' => e.message, 'hash' => {}}
      end

      def get(url, headers = {}, external_options = {print_log: false})
        response = RestClient.get(url, default_header.merge(headers)).force_encoding('UTF-8')
        if external_options[:print_log]
          puts "get #{url}"
          puts "response code: #{response.code}"
          puts "response body: \n#{JSON.pretty_generate(JSON.parse(response.body))}"
        end
        {'code' => response.code, 'body' => response.body, 'hash' => JSON.parse(response.body)}
      rescue => e
        puts "#{__FILE__}@#{__LINE__}: #{e.message}"
        {'code' => 500, 'body' => e.message, 'hash' => {}}
      end

      def download_version_file(url, path, job_uuid)
        response, btime, ptime = nil, Time.now, Time.now
        File.open(path, 'w:utf-8') do |file|
          execute_job_logger('下载预告: 每十秒打印报告', job_uuid)
          block = proc { |response|
            response.read_body do |chunk|
              file.write chunk.force_encoding('UTF-8')
              if Time.now - ptime > 10
                execute_job_logger("已下载文件大小 #{File.exists?(path) ? File.size(path).number_to_human_size : '0'}", job_uuid)
                ptime = Time.now
              end
            end
          }

          response = RestClient::Request.execute(method: :get, url: url, block_response: block)
        end
        response
      end

      protected
          
      def _timestamp
        Time.now.strftime('%y-%m-%d %H:%M:%S')
      end

      def execute_job_logger(info, job_uuid = nil)
        message = "#{_timestamp} - #{info}"
        if job_uuid
          output_path = File.join(ENV['RAKE_ROOT_PATH'], "db/jobs/#{job_uuid}/job.output")
          File.open(output_path, 'a+:utf-8') { |file| file.puts(message) }

          sandbox_path = File.join(ENV['RAKE_ROOT_PATH'], "db/jobs/#{job_uuid}")
          job_output_path = File.join(sandbox_path, 'job.output')
          job_output = File.exists?(job_output_path) ? IO.read(job_output_path) : "无输出"
          post_to_server_job({uuid: job_uuid, state: 'executing', output: job_output})
        else
          puts message
        end
      rescue => e
        puts "#{__FILE__}@#{__LINE__}: #{e.message}"
      end
    end
  end
end