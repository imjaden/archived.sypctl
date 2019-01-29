# encoding: utf-8
require 'fileutils'
require 'digest/md5'

# Assets Resource
class AssetHandler < Sinatra::Base
  configure do
    enable :logging, :static, :sessions
    enable :method_override
    enable :coffeescript
    
    set :root,  ENV['APP_ROOT_PATH']
    set :views, ENV['VIEW_PATH']
    set :public_folder, ENV['APP_ROOT_PATH'] + '/server/assets'
    set :js_dir,  ENV['APP_ROOT_PATH'] +  '/server/assets/javascripts'
    set :css_dir, ENV['APP_ROOT_PATH'] + '/server/assets/stylesheets'

    set :haml, layout_engine: :haml, layout: :'server/layout'
    set :cssengine, 'css'
  end
end

class ExceptionHandling
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call env
  rescue => ex
    env['rack.errors'].puts ex
    env['rack.errors'].puts ex.backtrace
    env['rack.errors'].flush

    hash = { message: ex.to_s }

    if ENV['RACK_ENV'].eql?('development')
      hash[:backtrace] = ex.backtrace
    end

    [500, { 'Content-Type' => 'application/json' }, [hash.to_json]]
  end
end

module AssetSprocketsHelpers
  def asset_path(source)
    "/sypctl/assets/" + settings.sprockets.find_asset(source).digest_path
  rescue => e
    puts "source: " + source
    puts e.message
    source
  end
end