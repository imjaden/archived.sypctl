# encoding: utf-8
require 'lib/utils/qiniu_instance_methods'

namespace :qiniu do

  desc 'upload the unupload and download the local not exist gravatars'
  task upload_and_download_gravatar: :environment do
    Rake::Task['qiniu:upload_gravatar'].invoke   
    Rake::Task['qiniu:download_gravatar'].invoke 
  end

  desc 'upload user gravatar to qiniu'
  task upload_gravatar: :environment do
    include ::QiniuInstanceMethods

    gravatar_folder = File.join(ENV['APP_ROOT_PATH'], 'public/gravatar')
    UserGravatar.where(is_upload_cdn: false).each do |record|
      gravatar_path = File.join(gravatar_folder, record.filename)
      unless File.exist?(gravatar_path)
        record.update(is_upload_cdn: false, upload_description: %(文件不存在 - #{gravatar_path}))
        next
      end

      code, result, response_headers = upload_file_2_qiniu(gravatar_path)
      record.update(is_upload_cdn: code == 200, upload_description: [code, result, response_headers].join(';'))
    end
  end

  desc 'download user gravatar when local not exist'
  task download_gravatar: :environment do
    gravatar_folder = File.join(ENV['APP_ROOT_PATH'], 'public/gravatar')
    UserGravatar.where(is_upload_cdn: true).each do |record|
      gravatar_path = File.join(gravatar_folder, record.filename)
      next if File.exist?(gravatar_path)

      download_url = "%s/%s" % [Setting.qiniu.out_link, record.filename]
      curl_command = "curl -o %s %s" % [gravatar_path, download_url]
      system(curl_command);
      puts %(download #{download_url} #{File.exist?(gravatar_path) ? 'successfully' : 'failed'}.)
    end
  end
end
