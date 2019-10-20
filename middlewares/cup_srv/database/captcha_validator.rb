#file: captcha_validator.rb
$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'log4r'
require 'net/http'
require 'openssl'

include Log4r

module MyGameServer
  class CaptchaValidator
    attr_reader :success, :last_error

    def initialize(secret)
      #verify captacha with an api call https://www.google.com/recaptcha/api/siteverify
      @log = Log4r::Logger["DbConnector"]
      @secret = secret
      @uri = URI('https://www.google.com/recaptcha/api/siteverify')
    end

    def validate(token)
      @success = false
      @last_error = ''
      @log.debug "Validate token using uri: #{@uri}"

      params = {
        'secret' => @secret,
        'response' => token
      }
      # Nota come vie usato https
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      #p @secret
      #p @uri.request_uri
      #p @uri.path
      request = Net::HTTP::Post.new(@uri.request_uri)
      request.form_data = params

      #p request.body
      res = http.request(request)
      p resp_json =  JSON.parse(res.body)
      @success = resp_json["success"]
      @last_error = resp_json["error-codes"].to_s 
      @log.debug "token verification is #{@success}"
      # body is something like:
      #{
      #    "success": true,
      #    "challenge_ts": "2018-02-24T19:12:53Z",
      #    "hostname": "localhost"
      #}
      #in case of error: {"success"=>false, "challenge_ts"=>"2018-02-24T19:12:53Z", "hostname"=>"localhost", "error-codes"=>["timeout-or-duplicate"]}
      return @success
    end
  end
end