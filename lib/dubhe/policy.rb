# frozen_string_literal: true

require "pathname"
require "uri"
require "jabbah"

module Dubhe
  class Policy
    class Denied < Dubhe::Error; end
    Result = Data.define(:html, :document, :blocked_count)

    attr_reader :profile

    def initialize(profile: :feed)
      @profile = profile
    end

    def apply(input, base_url: nil, allow_remote_images: false, on_blocked: nil)
      urls = []
      profile_options = Jabbah::Sanitize::PROFILES.fetch(profile.to_sym, Jabbah::Sanitize::DEFAULT).merge(
        allow_remote_images: allow_remote_images)
      document = Jabbah::Sanitize.clean(input, profile: profile_options, base_url: base_url,
        on_blocked: lambda do |url|
          urls << url
          on_blocked&.call(url)
        end,
        allow: Jabbah::Sanitize::DEFAULT)
      Result.new(html: document.to_html, document: document, blocked_count: urls.length)
    end

    def resolve_local(root, path)
      root_path = Pathname.new(root.to_s).expand_path
      raise Denied, "source root does not exist: #{root}" unless root_path.directory?

      candidate = root_path.join(path.to_s).cleanpath
      root_real = root_path.realpath
      candidate_real = candidate.realpath
      return candidate_real.to_s if candidate_real == root_real || candidate_real.to_s.start_with?("#{root_real}#{File::SEPARATOR}")

      raise Denied, "path escapes source root: #{path}"
    rescue Errno::ENOENT
      # Check the nearest existing parent so a new path cannot escape via .. .
      parent = candidate
      parent = parent.parent until parent.exist? || parent.root?
      parent_real = parent.realpath
      return candidate.to_s if parent_real == root_real || parent_real.to_s.start_with?("#{root_real}#{File::SEPARATOR}")

      raise Denied, "path escapes source root: #{path}"
    end

    def external_url?(url)
      scheme = URI.parse(url.to_s).scheme.to_s.downcase
      %w[http https mailto].include?(scheme)
    rescue URI::InvalidURIError
      false
    end
  end
end
