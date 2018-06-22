# encoding: utf-8
require 'sinatra/multi_route'

class ApplicationController < Sinatra::Base
  register Sinatra::Reloader unless ENV['RACK_ENV'].eql?('production')
  register Sinatra::MultiRoute
  register Sinatra::Logger
  register Sinatra::Flash

  use AssetHandler
  use ExceptionHandling

  set :root, ENV['APP_ROOT_PATH']
  set :rack_env, ENV['RACK_ENV']
  set :logger_level, :info
  enable :sessions, :logging, :static, :method_override
  enable :dump_errors, :raise_errors, :show_exceptions unless ENV['RACK_ENV'].eql?('production')

  set :views, ENV['VIEW_PATH']
  set :layout, :'layout'

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
    haml :'error', views: ENV['VIEW_PATH']
  end

  get '/', '/monitor' do
    @file_paths = Dir.glob(app_root_join("monitor/index/*.json"))
    @file_paths = @file_paths.sort_by { |path| File.mtime(path) }.reverse

    timestamps = @file_paths.map { |path| File.mtime(path) }

    haml :index, layout: settings.layout
  end

  get '/page', '/monitor/page' do
    @page_path = app_root_join("monitor/pages/#{params[:page]}")

    haml :page, layout: settings.layout
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
end
