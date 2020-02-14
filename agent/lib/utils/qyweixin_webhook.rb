# encoding:utf-8
# referenced: https://work.weixin.qq.com/api/doc/90000/90136/91770
require "erb"
require 'json'
require "base64"
require "openssl"
require 'rest-client'

module QyWeixin
  module Webhook
    class << self
      def send(key, payload)
        qyapi = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=#{key}"
        # payload = {
        #   msgtype: 'text',
        #   text: {
        #     content: content
        #   }
        # }
        headers = {
          content_type: :json,
          accept: :json
        }
        response = RestClient.post(qyapi, payload.to_json, headers)
        {
          code: response.code, 
          body: response.body, 
          hash: JSON.parse(response.body)
        }
      end

      alias_method :send_guard_nofity, :send
    end
  end
end
