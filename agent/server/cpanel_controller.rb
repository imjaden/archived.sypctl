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
      when 'register', 'service', 'service_output', 'file_backup', 'mysql_backup', 'packages'
        {message: "获取成功", data: send("get_data_#{params[:id]}")}
      else
        {message: "未知 id #{params[:id]}", data: {}}
      end

      respond_with_json({data: data}, 200)
    end

    get '/file_backup/:type' do
      file_path = File.join(ENV['APP_ROOT_PATH'], 'db/file-backups/archived', params[:archive_file_name])
      if params[:type] == 'read'
        data = File.exists?(file_path) ? File.read(file_path) : "文档不存在 #{file_path}"
        respond_with_json({data: data, message: "读取成功"}, 200)
      else
        halt_with_json({data: params[:archive_file_name], message: "文档不存在"}, 200) unless File.exists?(file_path) 
      
        send_file(file_path, type: 'text/plain', filename: params[:archive_file_name], disposition: 'attachment')
      end
    end

    protected

    def get_data_packages
      packages = `sypctl toolkit package files`.to_s.split("\n")
      data = packages.map do |package|
        file_name, file_md5 = package.split('@')
        package_path = app_root_join("../linux/packages/#{file_name}")
        package_state = File.exists?(package_path) ? '已安装' : '未安装'
        package_size = File.exists?(package_path) ? File.size(package_path).number_to_human_size(true).split(/\s/)[0] : '-'
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
      if File.exists?(json_path)
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
      if File.exists?(json_path)
        JSON.parse(File.read(json_path))
      else
        {'error': '配置档不存在，' + json_path}
      end
    end

    def get_data_service_output
      json_path = '/etc/sypctl/services.output'
      if File.exists?(json_path)
        {timestamp: Time.now.strftime('%Y/%m/%d %H:%M:%S')}.merge(JSON.parse(File.read(json_path)))
      else
        {'error': '配置档不存在，' + json_path}
      end
    end

    def get_data_file_backup
      local_db_path = File.join(ENV['APP_ROOT_PATH'], 'db/file-backups/synced.json')
      
      JSON.parse(File.read(local_db_path)).values
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
  end
end
