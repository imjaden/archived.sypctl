# encoding:utf-8
# referenced: https://github.com/Tassandar/aliyun-sms
require "erb"
require 'json'
require "base64"
require "openssl"
require 'rest-client'

include ERB::Util

module Aliyun
  module Sms
    class Configuration
      attr_accessor :access_key_secret, :access_key_id, :action, :format, :region_id,
                    :sign_name, :signature_method, :signature_version, :sms_version,
                    :domain

      def initialize
        @access_key_secret = ''
        @access_key_id = ''
        @action = ''
        @format = ''
        @region_id = ''
        @sign_name = ''
        @signature_method = ''
        @signature_version = ''
        @sms_version = ''
        @domain = ''
      end
    end

    class << self
      attr_writer :configuration

      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      def create_params(mobile_num, template_code, message_param)
        sms_params ={
          'AccessKeyId' => configuration.access_key_id,
          'Action' => configuration.action,
          'Format' => configuration.format,
          'PhoneNumbers' => mobile_num,
          'RegionId' => configuration.region_id,
          'SignName' => configuration.sign_name,
          'SignatureMethod' => configuration.signature_method,
          'SignatureNonce' => seed_signature_nonce,
          'SignatureVersion' => configuration.signature_version,
          'TemplateCode' => template_code,
          'TemplateParam' => message_param,
          'Timestamp' => seed_timestamp,
          'Version' => configuration.sms_version,
        }
      end

      def send(mobile_num, template_code, message_param)
        sms_params = create_params(mobile_num, template_code, message_param)
        query_params = get_query_params(configuration.access_key_secret, sms_params)
        response = RestClient.get("#{configuration.domain}?#{query_params}")
        {'code' => response.code, 'body' => response.body, 'hash' => JSON.parse(response.body)}
      end

      def send_guard_nofity(options)
        configure do |config|
          config.sign_name = options['sign_name']                 # 短信签名，在阿里云申请开通短信服务时申请获取
          config.access_key_id = options['access_key_id']         # 阿里云接入 ID, 在阿里云控制台申请
          config.access_key_secret = options['access_key_secret'] # 阿里云接入密钥，在阿里云控制台申请
          config.action = 'SendSms'                    # 默认设置，如果没有特殊需要，可以不改
          config.format = 'JSON'                       # 短信推送返回信息格式，可以填写 'JSON'或者'XML'
          config.region_id = 'cn-hangzhou'             # 默认设置，如果没有特殊需要，可以不改      
          config.signature_method = 'HMAC-SHA1'        # 加密算法，默认设置，不用修改
          config.signature_version = '1.0'             # 签名版本，默认设置，不用修改
          config.sms_version = '2017-05-25'            # 服务版本，默认设置，不用修改
          config.domain = 'dysmsapi.aliyuncs.com'      # 阿里云短信服务器, 默认设置，不用修改
        end

        [options['mobiles']].flatten.compact.uniq.map do |mobile|
          result = send(mobile, options['template_id'], options['template_options'])
          result['mobile'] = mobile
          result['template_id'] = options['template_id']
          result['template_options'] = options['template_options']
          result
        end
      end

      # 原生参数经过2次编码拼接成标准字符串
      def canonicalized_query_string(params)
        cqstring = ''

        # Canonicalized Query String/使用请求参数构造规范化的请求字符串
        # 按照参数名称的字典顺序对请求中所有的请求参数进行排序
        params = params.sort.to_h

        params.each do |key, value|
          if cqstring.empty?
            cqstring += "#{encode(key)}=#{encode(value)}"
          else
            cqstring += "&#{encode(key)}=#{encode(value)}"
          end
        end
        return cqstring
      end

      # 生成数字签名
      def sign(key_secret, params)
        key = key_secret + '&'
        signature = 'GET' + '&' + encode('/') + '&' + encode(canonicalized_query_string(params))
        digest = OpenSSL::Digest.new('sha1')
        sign = Base64.encode64(OpenSSL::HMAC.digest(digest, key, signature))
        encode(sign.chomp) # 通过chomp去掉最后的换行符 LF
      end

      # 组成附带签名的 GET 方法的 QUERY 请求字符串
      def get_query_params(key_secret, params)
        query_params = 'Signature=' + sign(key_secret, params) + '&' + canonicalized_query_string(params)
      end

      # 对字符串进行 PERCENT 编码
      def encode(input)
        output = url_encode(input)
        # useless replace, according to https://help.aliyun.com/document_detail/56189.html
        output.gsub(/\+/, '%20')
              .gsub(/\*/, '%2A')
              .gsub(/%7E/, '~')
      end

      # 生成短信时间戳
      def seed_timestamp
        Time.now.utc.strftime("%FT%TZ")
      end

      # 生成短信唯一标识码，采用到微秒的时间戳
      def seed_signature_nonce
        Time.now.utc.strftime("%Y%m%d%H%M%S%L")
      end

    end

  end
end

# options = {
#   sign_name: '胜因学院',
#   access_key_id: 'access_key_id',
#   access_key_secret: 'access_key_secret',
#   mobiles: ['13564379606'],
#   template_id: 'SMS_95610395',
#   template_options: "{\"customer\":\"jaden\"}"
# }
# Aliyun::Sms.send_guard_nofity(JSON.parse(options.to_json))
