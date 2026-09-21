# frozen_string_literal: true

module Dubhe
  module Source
    def id = raise NotImplementedError
    def title = raise NotImplementedError
    def icon = nil
    def refresh = raise NotImplementedError
    def entries(filter: nil) = raise NotImplementedError
    def fetch_body(_entry) = raise NotImplementedError
    def supports?(capability) = %i[refresh search unread].include?(capability)
  end
end
