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
      when 'register', 'service', 'service_output', 'backup', 'packages'
        {message: "获取成功", data: send("get_data_#{params[:id]}")}
      else
        {message: "未知 id #{params[:id]}", data: {}}
      end

      respond_with_json({data: data}, 200)
    end

    protected

    def get_data_packages
      packages = `sypctl package files`.to_s.split("\n")
      data = packages.map do |package|
        package_path = app_root_join("../linux/packages/#{package}")
        package_state = File.exists?(package_path) ? '已安装' : '未安装'
        package_size = File.exists?(package_path) ? File.size(package_path).number_to_human_size : '-'
        [package, package_size, package_state]
      end
      {
        heads: ['包名', '大小', '安装状态'],
        widths: ['60%', '20%', '20%'],
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

    def get_data_backup
      json_path = '/etc/sypctl/backup.json'
      if File.exists?(json_path)
        JSON.parse(File.read(json_path))
      else
        {'error': '配置档不存在，' + json_path}
      end
    end

  end
end
