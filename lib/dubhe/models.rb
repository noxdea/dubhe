# frozen_string_literal: true

module Dubhe
  Entry = Data.define(:id, :source_id, :title, :author, :published_at, :updated_at,
    :url, :summary, :tags, :state, :parent_id)
  Body = Data.define(:kind, :content, :base_url, :attachments, :headers)

  Subscription = Data.define(:id, :title, :url, :site_url, :group, :etag, :last_modified,
    :interval, :next_refresh_at, :failures)

  class Entry
    def read? = state == :read
    def starred? = state == :starred
  end
end
