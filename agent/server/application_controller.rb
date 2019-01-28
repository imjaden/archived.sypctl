# encoding: utf-8
require "sinatra/cookies"
require 'sinatra/multi_route'

class ApplicationController < Sinatra::Base
  register Sinatra::Reloader unless ENV['RACK_ENV'].eql?('production')
  register Sinatra::MultiRoute
  register Sinatra::Flash
  helpers Sinatra::Cookies

  use AssetHandler
  use ExceptionHandling

  set :root, ENV['APP_ROOT_PATH']
  set :rack_env, ENV['RACK_ENV']
  set :logger_level, :info
  enable :sessions, :logging, :static, :method_override
  enable :dump_errors, :raise_errors, :show_exceptions unless ENV['RACK_ENV'].eql?('production')

  set :views, File.join(ENV['VIEW_PATH'], 'views')
  set :layout, :layout

  # sprockets
  set :sprockets, Sprockets::Environment.new(root) { |env| env.logger = Logger.new(STDOUT) }
  set :precompile, [ /\w+\.(?!js|css).+/, /dist.(css|js)$/ ]
  set :assets_prefix, 'assets'
  set :assets_path, File.join(root, 'public', assets_prefix)

  configure do
    set :digest_assets,   false
    set :manifest_assets, false

    sprockets.cache = Sprockets::Cache::FileStore.new('./tmp')
    sprockets.register_compressor 'application/javascript', :uglify, Sprockets::UglifierCompressor.new(harmony: true)
    sprockets.js_compressor = :uglify
    sprockets.css_compressor = YUI::CssCompressor.new

    sprockets.append_path(File.join(ENV['VIEW_PATH'], 'assets/stylesheets'))
    sprockets.append_path(File.join(ENV['VIEW_PATH'], 'assets/javascripts'))

    sprockets.context_class.instance_eval do
      include AssetSprocketsHelpers
    end
  end
  
  helpers do
    include AssetSprocketsHelpers

    def flash_message
      return if !defined?(flash) || flash.empty?
      return flash.to_json
    end
  end

  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'origin, x-csrftoken, content-type, accept'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST'
    response.headers["P3P"] = "CP='IDC DSP COR ADM DEVi TAIi PSA PSD IVAi IVDi CONi HIS OUR IND CNT'"

    request_hash = request_params
    @params = request_hash.is_a?(Hash) ? params.merge(request_hash) : params
    @params[:ip] ||= request.ip
    @params[:browser] ||= request.user_agent

    print_format_logger
  end

  not_found do
    respond_with_json({ info: 'route not found', method: request.request_method, url: request.url }, 404)
  end

  error do
    haml :error, views: ENV['VIEW_PATH']
  end

  get "/sypctl-assets/*" do
    env['PATH_INFO'].sub!(%r{^/sypctl-assets}, '')
    settings.sprockets.call(env)
  end

  get '/', '/monitor' do
    haml :index, layout: settings.layout
  end

  get '/data' do
    file_paths = Dir.glob(app_root_join("monitor/index/*.json"))
    file_paths = file_paths.sort_by { |path| File.mtime(path) }.reverse
    data = file_paths.map do |file_path|
      config = JSON.parse(IO.read(file_path))
      config["title"] ||= File.basename(file_path, ".json") 
      config['description'] ||= '文档描述为空'
      config["headings"] ||= []
      config["width"] ||= (config["headings"].empty? ? [] : Array.new(config["headings"].length) { "#{100.0/config["headings"].length}%" })
      config
    end

    respond_with_json({data: data, message: '获取数据成功'}, 200)
  end

  get '/index', '/info' do
    index_path = app_root_join("monitor/index/index.html")
    if File.exists?(index_path)
      File.read(index_path)
    else
      "#{ENV['PLATFORM_OS']}:#{ENV['APP_RUNNER']}@#{ENV['HOSTNAME']} sypctl agent server"
    end
  end

  get '/page', '/monitor/page' do
    @page_path = app_root_join("monitor/pages/#{params[:page]}")

    if File.exists?(@page_path)
      haml :page, layout: settings.layout
    else
      "404 - File Not Found!"
    end
  end

  post '/login' do
    expect_username = 'sypctl'
    expect_password = File.read(File.join(ENV['APP_ROOT_PATH'], '.config/password')).strip

    message = expect_username == params[:username] && expect_password == params[:password] ? '登录成功' : '登录失败，账号或密码错误'
    set_login_cookie(message)

    respond_with_json({message: message, code: 201}, 201)
  end

  get '/logout' do
    set_login_cookie(nil)

    flash[:success] = '登出成功'
    redirect to('/')
  end

  get '/ping' do
    'pong'
  end

  protected

  # global functions list
  def app_root_join(path)
    File.join(settings.root, path)
  end

  def app_tmp_join(path)
    File.join(settings.root, 'tmp', path)
  end

  def print_format_logger
    logger.info <<-EOF.strip_heredoc
      #{request.request_method} #{request.path} for #{request.ip} at #{Time.now}
      Parameters:
        #{@params}
    EOF
  end

  def request_params(raw_body = request.body)
    body = case raw_body
    when StringIO
     raw_body.string
    when Tempfile,
     # gem#unicorn
     #     change the strtucture of REQUEST
     (defined?(Unicorn) && Unicorn::TeeInput),
     # gem#passenger is ugly!
     #     change the structure of REQUEST
     #     detail at: https://github.com/phusion/passenger/blob/master/lib/phusion_passenger/utils/tee_input.rb
     (defined?(PhusionPassenger) && PhusionPassenger::Utils::TeeInput),
     (defined?(Rack) && Rack::Lint::InputWrapper)

     raw_body.read # if body.respond_to?(:read)
    else
     raw_body.to_str
    end.to_s.strip

    JSON.parse(body) if !body.empty? && body.start_with?('{') && body.end_with?('}')
  rescue => e
    logger.error %(request_params - #{e.message})
  end

  def respond_with_json(response_hash = {}, code = 200)
    response_hash[:code] ||= code
    logger.info response_hash.to_json

    content_type 'application/json', charset: 'utf-8'
    body response_hash.to_json
    status code
  end

  def halt_with_json(response_hash = {}, code = 200)
    response_hash[:code] ||= code
    logger.info response_hash.to_json

    content_type 'application/json', charset: 'utf-8'
    halt(code, {'Content-Type' => 'application/json;charset=utf-8'}, response_hash.to_json)
  end

  def set_seo_meta(title = '', meta_keywords = '', meta_description = '')
    @page_title       = title
    @meta_keywords    = meta_keywords
    @meta_description = meta_description
  end

  def cache_with_custom_defined(timestamps = [], etag_content = nil)
    return if ENV['RACK_ENV'] == 'development'

    timestamp = timestamps.compact.max
    timestamp ||= (settings.startup_time || Time.now)

    last_modified timestamp
    etag md5(etag_content || timestamp)
  end

  def read_json_guard(json_path, default_return = [])
    return default_return unless File.exist?(json_path)

    json_hash = JSON.parse(IO.read(json_path))
    return default_return unless json_hash.is_a?(Array)
    json_hash
  rescue
    File.delete(json_path) if File.exist?(json_path)
    default_return
  end

  def json_format?(content)
    ::JSON.parse(content)
    true
  rescue
    false
  end

  def parse_json_to_hash(content)
    json = JSON.parse(content)
    if json.is_a?(Hash)
      json = json.deep_symbolize_keys
    elsif json.is_a?(Array)
      json = json.map do |item|
        item = item.deep_symbolize_keys if item.is_a?(Hash)
        item
      end
    end
    json
  rescue => e
    {code: 500, exception: e.message, message: 'exception'}
  end

  def set_login_cookie(_cookie_value = '')
    if _cookie_value == '登录成功'
      cookies[cookie_name] = _cookie_value
    else
      cookies.delete(cookie_name)
    end
  end

  def authenticate!
    return if cookies[cookie_name]

    flash[:warning] = '身份验证失败，请登录'
    redirect '/', 302
  end

  def cookie_name
    @cookie_name ||= begin
      "authen-sypctl-agent-#{ENV['SYPCTL_VERSION']}"
    end
  end
end
