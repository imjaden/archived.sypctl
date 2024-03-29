# encoding: utf-8
module Cpanel
  class ApplicationController < ::ApplicationController
    set :views, File.join(ENV['VIEW_PATH'], 'views')
    set :layout, :layout

    before do
      authenticate!
      @page_title = '管理中心'
    end

    get '/' do
      haml :cpanel, layout: settings.layout
    end

    get '/data/:id' do
      data = case params[:id]
      when 'register', 'service', 'service_output', 'file_backup', 'mysql_backup', 'packages', 'sypetl_sendmail'
        {message: "获取成功", data: send("get_data_#{params[:id]}")}
      else
        {message: "未知 id #{params[:id]}", data: {}}
      end

      respond_with_json({data: data}, 200)
    end

    post '/data/:id' do
      save_config_file(params[:id], params[:config])

      respond_with_json({message: '保存成功'}, 201)
    end

    get '/file_backup/:type' do
      file_path = File.join(ENV['APP_ROOT_PATH'], 'db/file-backups/snapshots', params[:snapshot_filename])
      if params[:type] == 'read'
        data = File.exist?(file_path) ? File.read(file_path) : "文档不存在 #{file_path}"
        respond_with_json({data: data, message: "读取成功"}, 200)
      else
        halt_with_json({data: params[:snapshot_filename], message: "文档不存在"}, 200) unless File.exist?(file_path) 
      
        send_file(file_path, type: 'text/plain', filename: params[:snapshot_filename], disposition: 'attachment')
      end
    end

    protected

    def save_config_file(id, config)
      filepath = case params[:id]
      when 'service' then '/etc/sypctl/services.json'
      when 'file_backup' then '/etc/sypctl/backup-file.json'
      when 'mysql_backup' then '/etc/sypctl/backup-mysql.json'
      when 'sypetl_sendmail' then '/data/work/config/sypetl-sendmail.json'
      else '/etc/sypctl/unknown.json'
      end
      File.open(filepath, 'w:utf-8') { |file| file.puts(config) }
    end

    def get_data_packages
      packages = `sypctl toolkit package files`.to_s.split("\n")
      data = packages.map do |package|
        file_name, file_md5 = package.split('@')
        package_path = app_root_join("../linux/packages/#{file_name}")
        package_state = File.exist?(package_path) ? '已安装' : '未安装'
        package_size = File.exist?(package_path) ? File.size(package_path).number_to_human_size(true).split(/\s/)[0] : '-'
        [file_name, package_size, file_md5, package_state]
      end
      {
        heads: ['包名', '大小', '哈希', '安装状态'],
        widths: ['50%', '8%', '34%', '8%'],
        rows: data,
        timestamp: Time.now.strftime('%Y/%m/%d %H:%M:%S')
      }
    rescue => e
      {'error': e.message}
    end

    def get_data_register
      json_path = File.join(ENV['APP_ROOT_PATH'], 'db/agent.json')
      if File.exist?(json_path)
        JSON.parse(File.read(json_path))
      else
        {'error': '配置档不存在，' + json_path}
      end
    end

    def get_data_service
      {service:get_data_service_config, output: get_data_service_output }
    end

    def get_data_service_config
      json_path = '/etc/sypctl/services.json'
      if File.exist?(json_path)
        JSON.parse(File.read(json_path))
      else
        {'error': '配置档不存在，' + json_path}
      end
    end

    def get_data_service_output
      json_path = '/etc/sypctl/services.output'
      if File.exist?(json_path)
        {timestamp: Time.now.strftime('%Y/%m/%d %H:%M:%S')}.merge(JSON.parse(File.read(json_path)))
      else
        {'error': '配置档不存在，' + json_path}
      end
    end

    def get_data_file_backup
      snapshots = Dir.glob("#{ENV['APP_ROOT_PATH']}/db/file-backups/*-snapshot.json").to_a.map do |snapshot_path|
        JSON.parse(File.read(snapshot_path))
      end
      
      snapshots
    rescue => e
      puts e.message
      puts e.backtrace.select { |s| s.start_with?(Dir.pwd) }
      {'error': '配置档不存在'}
    end

    def get_data_mysql_backup
      config_path = '/etc/sypctl/backup-mysql.json'
      
      { 
        path: config_path,
        config: JSON.parse(File.read(config_path))
      }
    rescue => e
      puts e.message
      puts e.backtrace.select { |s| s.start_with?(Dir.pwd) }
      {'error': '配置档不存在'}
    end

    def get_data_sypetl_sendmail
      config_path = '/data/work/config/sypetl-sendmail.json'
      
      { 
        path: config_path,
        config: JSON.parse(File.read(config_path))
      }
    rescue => e
      puts e.message
      puts e.backtrace.select { |s| s.start_with?(Dir.pwd) }
      {'error': '配置档不存在'}
    end
  end
end
