# encoding: utf-8
require 'json'
require 'mysql2'

module Sypctl
  class MySQL
    class << self
      # {
      #   :host => "localhost", 
      #   :username => "username",
      #   :password => "password"
      # }
      def init(config, force = false)
        @client = nil if force
        @client ||= Mysql2::Client.new(config)
      end

      def query(sql)
        @client.query(sql)
      end

      def report
        path = '/etc/sypctl/backup-mysql.json'
        return unless File.exists?(path)

        mysqls = JSON.parse(File.read(path))
        mysqls.map do |mysql|
          config = mysql['config']
          init(config, true)

          in_use_length = query('show open tables where in_use > 0;').to_a.length
          in_execte_length = query("select * from information_schema.processlist where user = '#{config['username']}' and length(info) > 0 and info not like '%processlist%'").to_a.length
          
          {
            host: "#{config['host']}:#{config['port'] || 3306}",
            username: config['username'],
            in_use: in_use_length,
            in_execte: in_execte_length
          }
        end
      end

      def print_report
        puts JSON.pretty_generate(report || {})
      end
    end
  end
end
