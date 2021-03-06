# encoding: utf-8
require 'json'
require 'fileutils'
require 'rest-client'
require 'securerandom'
require File.expand_path('../../core_ext/string.rb', __FILE__)
require File.expand_path('../../core_ext/numberic.rb', __FILE__)

ENV["SYPCTL_API"] = "https://api.sypctl.com"

module Sypctl
  class Http
    class << self
      def default_header
        {'User-Agent' => "sypctl #{ENV['SYPCTL_VERSION']};#{ENV['RUBY_VERSION']}"} # 'Content-Type' => 'application/json', 
      end

      def post(url, playload = {}, headers = {}, external_options = {print_log: false})
        options = {
          url: url,
          playload: playload,
          headers: headers,
          external_options: external_options
        }
        rescue_method options do |options|
          response = RestClient.post(options[:url], options[:playload], default_header.merge(options[:headers]))
          if options[:external_options][:print_log]
            puts "post #{options[:url]}"
            puts "parameters: \n#{JSON.pretty_generate(playload)}"
            puts "response code: #{response.code}"
            puts "response body: \n#{JSON.pretty_generate(JSON.parse(response.body))}"
          end
          {'code' => response.code, 'body' => response.body, 'hash' => JSON.parse(response.body)}
        end
      end

      def get(url, headers = {}, external_options = {print_log: false})
        options = {
          url: url,
          headers: headers,
          external_options: external_options
        }
        rescue_method options do |options|
          response = RestClient.get(options[:url], default_header.merge(options[:headers])).force_encoding('UTF-8')
          if options[:external_options][:print_log]
            puts "get #{options[:url]}"
            puts "response code: #{response.code}"
            puts "response body: \n#{JSON.pretty_generate(JSON.parse(response.body))}"
          end
          {'code' => response.code, 'body' => response.body, 'hash' => JSON.parse(response.body)}
        end
      end

      def download_version_file(url, path, job_uuid)
        response = "?????????..."
        FileUtils.rm_f(path) if File.exists?(path)
        response = RestClient::Request.execute(method: :get, url: url, raw_response: true) #block_response: block)
        FileUtils.copy(response.file.path, path)
        response
      end

      def post_behavior(options = {}, headers = {}, external_options = {print_log: false})
        params = {}
        params[:url] = "#{ENV['SYPCTL_API']}/api/v1/agent/behavior_log"
        params[:headers] = headers
        params[:external_options] = external_options

        rescue_method params do |params|
          unless File.exists?(agent_db_path)
            puts "?????????????????????????????????????????????"
            return false 
          end

          agent_db_hash = JSON.parse(File.read(agent_db_path))
          playload = {
            behavior: {
              device_uuid: agent_db_hash['uuid'],
              device_name: agent_db_hash['human_name'] || agent_db_hash['hostname'],
              behavior: options[:behavior] || '',
              object_type: options[:object_type] || '',
              object_id: options[:object_id] || '',
              description: options[:description] || ''
            }
          }
          response = RestClient.post(params[:url], playload, default_header.merge(params[:headers]))
          if params[:external_options][:print_log]
            puts "post #{params[:url]}"
            puts "parameters: \n#{JSON.pretty_generate(playload)}"
            puts "response code: #{response.code}"
            puts "response body: \n#{JSON.pretty_generate(JSON.parse(response.body))}"
          end
          {'code' => response.code, 'body' => response.body, 'hash' => JSON.parse(response.body)}
        end
      end

      def post_backup_mysql_day(options = {}, headers = {}, external_options = {print_log: false})
        params = {}
        params[:url] = "#{ENV['SYPCTL_API']}/api/v1/agent/backup_mysql_day"
        params[:headers] = headers
        params[:external_options] = external_options
        
        rescue_method params do |params|
          unless File.exists?(agent_db_path)
            puts "?????????????????????????????????????????????"
            return false 
          end

          agent_db_hash = JSON.parse(File.read(agent_db_path))
          options[:device_uuid] = agent_db_hash['uuid']
          options[:device_name] = agent_db_hash['human_name'] || agent_db_hash['hostname']

          options.delete(:backup_command)
          options.delete(:ignore_tables)

          playload = {backup_mysql_day: options}
          response = RestClient.post(params[:url], playload, default_header.merge(params[:headers]))
          if params[:external_options][:print_log]
            puts "post #{params[:url]}"
            puts "parameters: \n#{JSON.pretty_generate(playload)}"
            puts "response code: #{response.code}"
            puts "response body: \n#{JSON.pretty_generate(JSON.parse(response.body))}"
          end
          {'code' => response.code, 'body' => response.body, 'hash' => JSON.parse(response.body)}
        end
      end

      def post_backup_mysql_meta(options = {}, headers = {}, external_options = {print_log: false})
        params = {}
        params[:url] = "#{ENV['SYPCTL_API']}/api/v1/agent/backup_mysql_meta"
        params[:headers] = headers
        params[:external_options] = external_options
        
        rescue_method params do |params|
          unless File.exists?(agent_db_path)
            puts "?????????????????????????????????????????????"
            return false 
          end

          agent_db_hash = JSON.parse(File.read(agent_db_path))
          options[:device_uuid] = agent_db_hash['uuid']
          options[:device_name] = agent_db_hash['human_name'] || agent_db_hash['hostname']

          playload = {backup_mysql_meta: options}
          response = RestClient.post(params[:url], playload, default_header.merge(params[:headers]))
          if params[:external_options][:print_log]
            puts "post #{params[:url]}"
            puts "parameters: \n#{JSON.pretty_generate(playload)}"
            puts "response code: #{response.code}"
            puts "response body: \n#{JSON.pretty_generate(JSON.parse(response.body))}"
          end
          {'code' => response.code, 'body' => response.body, 'hash' => JSON.parse(response.body)}
        end
      end

      def send_sms(options = {}, headers = {}, external_options = {print_log: false})
        params = {}
        params[:url] = "#{ENV['SYPCTL_API']}/api/v1/send_sms"
        params[:headers] = headers
        params[:external_options] = external_options

        rescue_method params do |params|
          unless File.exists?(agent_db_path)
            puts "?????????????????????????????????????????????"
            return false 
          end

          agent_db_hash = JSON.parse(File.read(agent_db_path))
          options[:creater_uuid] = agent_db_hash['uuid']
          options[:creater_name] = "sypaget@" + (agent_db_hash['human_name'] || agent_db_hash['hostname'])

          response = RestClient.post(params[:url], options, default_header.merge(params[:headers]))
          if params[:external_options][:print_log]
            puts "post #{params[:url]}"
            puts "parameters: \n#{JSON.pretty_generate(options)}"
            puts "response code: #{response.code}"
            puts "response body: \n#{JSON.pretty_generate(JSON.parse(response.body))}"
          end
          {'code' => response.code, 'body' => response.body, 'hash' => JSON.parse(response.body)}
        end
      end

      protected
      
      def rescue_method(options, &block)
        yield(options)
      rescue Errno::ECONNREFUSED, RestClient::BadGateway
        puts "#" * 25
        puts "# ??????????????????????????? API ??????????????????"
        puts "# API: #{options[:url]}"
        puts "# ??????????????????"
        puts "#" * 25
        exit 1
      rescue => e
        options = {'code' => 500, 'body' => e.message, 'backtrace' => e.backtrace.select{ |line| line.include?(__FILE__)}}
        puts options
        return options
      end

      def _timestamp
        Time.now.strftime('%y-%m-%d %H:%M:%S')
      end

      def agent_db_path
        rake_root_path = ENV['RAKE_ROOT_PATH'] || Dir.pwd
        rake_root_path = "#{rake_root_path}/agent" if rake_root_path.split('/').last != 'agent'
        File.join(rake_root_path, 'db/agent.json')
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
        job_output = File.exists?(job_output_path) ? IO.read(job_output_path) : "?????????"
        post_to_server_job({uuid: job_uuid, state: 'executing', output: job_output})
      rescue => e
        puts "#{__FILE__}@#{__LINE__}: #{e.message}"
        puts e.backtrace.select{ |line| line.include?(__FILE__)}
      end
    end
  end
end

# url = "http://127.0.0.1:81/download-version/e413f39a88124c8497a3badf4e102aa8/6c20b473a03c444c8b1a8ce41cdffbb1.jar"
# version_file_path = "./6c20b473a03c444c8b1a8ce41cdffbb1.jar"
# Sypctl::Http.download_version_file(url, version_file_path, nil)
