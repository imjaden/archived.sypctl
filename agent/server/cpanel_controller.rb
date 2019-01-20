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
      when 'regisiter', 'service', 'service_output', 'backup', 'service_output'
        {message: "获取成功", data: send("get_data_#{params[:id]}")}
      else
        {message: "未知 id #{params[:id]}", data: {}}
      end

      respond_with_json({data: data}, 200)
    end

    protected

    def get_data_regisiter
      json_path = File.join(ENV['APP_ROOT_PATH'], 'db/agent.json')
      if File.exists?(json_path)
        JSON.parse(File.read(json_path))
      else
        {'error': '配置档不存在，' + json_path}
      end
    end

    def get_data_service
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
        JSON.parse(File.read(json_path))
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
