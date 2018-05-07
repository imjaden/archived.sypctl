# encoding:utf-8
desc 'tasks around CoffeeScript'
namespace :cs2js do
  def lasttime(info, &block)
    bint = Time.now.to_f
    yield
    eint = Time.now.to_f
    printf('%-10s - %s\n', format('[%dms]', ((eint - bint) * 1000).to_i), info)
  end

  desc 'CoffeeScript Complie file to JS file'
  task compile: :environment do
    assets_path = %(#{ENV['APP_ROOT_PATH']}/app/assets)
    javascript_path = %(#{assets_path}/javascripts)
    coffeescript_path = %(#{assets_path}/coffeescripts)
    coffeescripts = Dir.entries(coffeescript_path).select { |cs| cs if cs =~ /.*?\.coffee$/ }
    coffeescripts.each do |coffeescript_file|
      next if coffeescripts.empty?

      lasttime(format('%-25s - CoffeScript file Complie over.', coffeescript_file)) do
        file_path = File.join(coffeescript_path, coffeescript_file)
        target_path = File.join(javascript_path, File.basename(coffeescript_file.sub('.coffee', '.js')))
        File.open(target_path, 'w:utf-8') do |file|
          file.puts CoffeeScript.compile(File.read(file_path))
        end
      end
    end

    sass_path = %(#{assets_path}/sass)
    css_path = %(#{assets_path}/stylesheets)
    sass_files = Dir.entries(sass_path).select { |cs| cs if cs =~ /.*?\.scss$/ }
    sass_files.each do |sass_file|
      lasttime(format('%-25s - Scss file Complie over.', sass_file)) do
        file_path = File.join(sass_path, sass_file)
        target_path = File.join(css_path, File.basename(sass_file).sub('.scss', '.css'))
        File.open(target_path, 'w:utf-8') do |file|
          engine = Sass::Engine.new(File.read(file_path), syntax: :scss)
          file.puts engine.render
        end
      end
    end
  end
end
