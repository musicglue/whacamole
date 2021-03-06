require 'base64'
require 'net/http'
require 'json'

module Whacamole
  class HerokuWrapper
    attr_accessor :api_token, :app_name, :dynos

    RESTART_RATE_LIMIT = 30*60

    def initialize(app_name, api_token, dynos)
      self.app_name = app_name
      self.api_token = api_token
      self.dynos = dynos
    end

    def create_log_session
      uri = URI(log_sessions_url)
      req = Net::HTTP::Post.new(uri.path)
      req['Authorization'] = authorization
      req['Content-type'] = content_type
      req['Accept'] = accept
      req.set_form_data({'tail' => true})
      res = Net::HTTP.start(uri.host, uri.port, :use_ssl => (uri.scheme == "https")) {|http| http.request(req)}
      JSON.parse(res.body)['logplex_url']
    end

    def authorization
      "Basic " + Base64.encode64(":#{api_token}").gsub("\n", '')
    end

    def restart(process)
      return false if recently_restarted?(process)

      uri = URI(dyno_url(process))
      req = Net::HTTP::Delete.new(uri.path)
      req['Authorization'] = authorization
      req['Content-type'] = content_type
      req['Accept'] = accept
      res = Net::HTTP.start(uri.host, uri.port, :use_ssl => (uri.scheme == "https")) {|http| http.request(req)}

      restarts[process] = Time.now

      true
    end

    def recently_restarted?(process)
      restarts[process] > (Time.now - RESTART_RATE_LIMIT)
    end

    private
    def content_type
      "application/json"
    end

    def accept
      "application/vnd.heroku+json; version=3"
    end

    def log_sessions_url
      "https://api.heroku.com/apps/#{app_name}/log-sessions"
    end

    def dyno_url(process)
      "https://api.heroku.com/apps/#{app_name}/dynos/#{process}"
    end

    def restarts
      @restarts ||= Hash.new { Time.now - RESTART_RATE_LIMIT*2 }
    end
  end
end
