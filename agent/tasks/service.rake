# encoding: utf-8
require 'yaml'
require 'json'
require 'fileutils'

namespace :service do
  desc 'print SYPCTL_VERSION'
  task list: :environment do
    puts ENV["SYPCTL_VERSION"]
  end

  task load: :environment do
    services_filepath = File.join(ENV["EXECUTE_PATH"], ENV['services_filename'])
    if File.exists?(services_filepath)
      services_hash = JSON.parse(File.read(services_filepath))
      File.open(File.join(ENV["APP_ROOT_PATH"], "db/services.json"), "w:utf-8") do |file|
        file.puts(services_hash.to_json)
      end
      puts "load successfully!"
    else
      puts "services 文档读取失败:\n#{services_filepath}"
    end
  end

  task pluck: :environment do 
    services_path = File.join(ENV["APP_ROOT_PATH"], "db/services.json")
    if File.exists?(services_path)
      pluck_filepath = File.join(ENV["EXECUTE_PATH"], "services.json")
      File.open(pluck_filepath, "w:utf-8") do |file|
        file.puts(JSON.pretty_generate(JSON.parse(File.read(services_path))))
      end
      puts "pluck successfully!"
      puts pluck_filepath
    else
      puts " 该系统未配置 services"
    end
  end
end