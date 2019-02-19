# encoding: utf-8
require 'json'
require 'fileutils'
require 'rest-client'
require 'securerandom'
require File.expand_path('../../core_ext/string.rb', __FILE__)
require File.expand_path('../../core_ext/numberic.rb', __FILE__)

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
        response = "下载中..."
        FileUtils.rm_f(path) if File.exists?(path)
        response = RestClient::Request.execute(method: :get, url: url, raw_response: true) #block_response: block)
        FileUtils.copy(response.file.path, path)
        response
      end

      protected
          
      def _timestamp
        Time.now.strftime('%y-%m-%d %H:%M:%S')
      end

      def execute_job_logger(info, job_uuid = nil)
        message = "#{_timestamp} - #{info}"
        unless job_uuid
          puts message
          return false
        end

        output_path = File.join(ENV['RAKE_ROOT_PATH'], "db/jobs/#{job_uuid}/job.output")
        File.open(output_path, 'a+:utf-8') { |file| file.puts(message) }

        sandbox_path = File.join(ENV['RAKE_ROOT_PATH'], "db/jobs/#{job_uuid}")
        job_output_path = File.join(sandbox_path, 'job.output')
        job_output = File.exists?(job_output_path) ? IO.read(job_output_path) : "无输出"
        post_to_server_job({uuid: job_uuid, state: 'executing', output: job_output})
      rescue => e
        puts "#{__FILE__}@#{__LINE__}: #{e.message}"
      end
    end
  end
end

# url = "http://127.0.0.1:81/download-version/e413f39a88124c8497a3badf4e102aa8/6c20b473a03c444c8b1a8ce41cdffbb1.jar"
# version_file_path = "./6c20b473a03c444c8b1a8ce41cdffbb1.jar"
# Sypctl::Http.download_version_file(url, version_file_path, nil)
