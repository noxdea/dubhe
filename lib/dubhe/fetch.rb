# frozen_string_literal: true

require "net/http"
require "uri"

module Dubhe
  module Fetch
    Response = Data.define(:status, :headers, :body, :uri)

    class Client
      DEFAULT_USER_AGENT = "Dubhe/0.1 (+https://github.com/noxdea/dubhe)"
      REDIRECTS = %w[301 302 303 307 308].freeze

      def initialize(user_agent: DEFAULT_USER_AGENT, open_timeout: 10, read_timeout: 30, max_bytes: 10 * 1024 * 1024)
        @user_agent = user_agent
        @open_timeout = open_timeout
        @read_timeout = read_timeout
        @max_bytes = max_bytes
      end

      def get(url, headers: {}, redirects: 0)
        uri = URI.parse(url.to_s)
        raise Dubhe::Error, "only HTTP(S) URLs are supported" unless %w[http https].include?(uri.scheme)
        raise Dubhe::Error, "too many redirects" if redirects > 5

        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = @user_agent
        request["Accept"] = "application/rss+xml, application/atom+xml, application/feed+json, application/json, text/xml, text/html;q=0.8"
        headers.each { |key, value| request[key.to_s] = value.to_s unless value.nil? || value.to_s.empty? }
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
          open_timeout: @open_timeout, read_timeout: @read_timeout) do |http|
          http.request(request)
        end
        if REDIRECTS.include?(response.code)
          location = response["location"]
          raise Dubhe::Error, "redirect without location" unless location

          return get(URI.join(uri.to_s, location).to_s, headers: headers, redirects: redirects + 1)
        end
        body = response.body.to_s
        raise Dubhe::Error, "response exceeds size limit" if body.bytesize > @max_bytes

        Response.new(status: response.code.to_i, headers: response.each_header.to_h, body: body, uri: uri.to_s)
      rescue SocketError, Timeout::Error, IOError, SystemCallError => error
        raise Dubhe::Error, "fetch failed for #{url}: #{error.message}"
      end
    end
  end
end
