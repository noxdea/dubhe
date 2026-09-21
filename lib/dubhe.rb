# frozen_string_literal: true

require_relative "dubhe/version"

module Dubhe
  class Error < StandardError; end
end

require_relative "dubhe/models"
require_relative "dubhe/source"
require_relative "dubhe/policy"
require_relative "dubhe/store"
require_relative "dubhe/fetch"
require_relative "dubhe/render"
require_relative "dubhe/reader"
require_relative "dubhe/sources/feeds"
require_relative "dubhe/sources/docs"
require_relative "dubhe/sources/mail"
