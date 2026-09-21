# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "dubhe"

class FakeFetcher
  Response = Struct.new(:status, :headers, :body, :uri, keyword_init: true)

  attr_reader :requests

  def initialize(body, status: 200, headers: {})
    @body = body
    @status = status
    @headers = headers
    @requests = []
  end

  def get(url, headers: {})
    @requests << [url, headers]
    Response.new(status: @status, headers: @headers, body: @body, uri: url)
  end
end
