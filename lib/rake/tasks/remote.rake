# encoding: utf-8
require 'net/ssh'
require 'net/scp'
desc 'remote deploy application.'
namespace :remote do
  def encode(data)
    data.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
  end

  def execute!(ssh, command)
    ssh.exec!(command) do |_, stream, data|
      puts format('%s:\n%s', stream, encode(data))
    end
  end

  desc 'scp local config files to remote server.'
  task deploy: :environment do
    remote_root_path = Setting.server.app_root_path
    # local_config_path = %(#{ENV['APP_ROOT_PATH']}/lib/templates/*.json)
    # remote_config_path = %(#{remote_root_path}/lib/templates/)

    Net::SSH.start(Setting.server.host, Setting.server.user, password: Setting.server.password) do |ssh|
      command = %(cd #{remote_root_path} && git reset --hard HEAD && git pull)
      execute!(ssh, command)

      # check whether remote server exist yaml file
      # Dir.glob(local_config_path).each do |yaml_path|
      #   ssh.scp.upload!(yaml_path, remote_config_path) do |ch, name, sent, total|
      #     print '\rupload #{name}: #{(sent.to_f * 100 / total.to_f).to_i}%'
      #   end
      #   puts '\n'
      # end

      command = %(cd #{remote_root_path} && /bin/sh tool.sh stop)
      execute!(ssh, command)

      # command = 'cd %s && rm -f db/*.db' % remote_root_path
      # execute!(ssh, command)
      # command = 'cd %s && bundle exec rake db:seeds' % remote_root_path
      # execute!(ssh, command)

      command = %(cd #{remote_root_path} && /bin/sh tool.sh start)
      execute!(ssh, command)

      # command = 'source ~/.bash_profile && rbenv -v'
      # execute!(ssh, command)

      # database_name = '%s_%s' % [ENV['APP_NAME'], 'production']
      # remote_db_path = '%s/db/%s.db' % [remote_root_path, database_name]
      # local_db_path  = '%s/db/%s.db' % [ENV['APP_ROOT_PATH'], database_name]

      # File.delete(local_db_path) if File.exist?(local_db_path)
      # ssh.scp.download!(remote_db_path, local_db_path)
    end
  end
end
