# frozen_string_literal: true

require "base64"
require "digest"
require "ukdah"

module Dubhe
  module Sources
    class Mail
      include Source

      def initialize(path:, store: Store.new, policy: Policy.new(profile: :mail))
        @path = File.expand_path(path.to_s)
        @store = store
        @policy = policy
        @messages = {}
      end

      def id = "mail:#{Digest::SHA256.hexdigest(@path)}"
      def title = File.basename(@path)
      def icon = "mail"

      def refresh
        messages = if File.extname(@path).downcase == ".mbox"
                     Ukdah::Mbox.each(File.binread(@path)).to_a
                   else
                     [Ukdah::Message.parse(File.binread(@path))]
                   end
        entries = messages.map do |message|
          message_id = message.message_id || Digest::SHA256.hexdigest(message.raw.to_s)
          entry = Entry.new(id: "#{id}:#{message_id}", source_id: id, title: message.subject.to_s,
            author: message.from.map { |address| address.respond_to?(:email) ? address.email : address.to_s }.join(", "),
            published_at: message.date, updated_at: message.date, url: nil, summary: message.header("x-snippet"),
            tags: [], state: :unread, parent_id: nil)
          @messages[entry.id] = message
          @store.save_entry(entry)
          @store.save_body(entry.id, fetch_body(entry))
          entry
        end
        entries
      end

      def entries(filter: nil)
        result = @store.entries(source_id: id)
        result = refresh if result.empty?
        filter ? result.select { |entry| filter.call(entry) } : result
      end

      def fetch_body(entry)
        message = @messages[entry.id]
        return @store.body(entry.id) unless message

        if (part = message.html_part)
          html = message.decoded(part)
          message.inline_parts.each do |content_id, inline_part|
            next if content_id.start_with?("<")

            mime = inline_part.content_type.to_s
            data = Base64.strict_encode64(inline_part.body.to_s)
            html = html.gsub("cid:#{content_id}", "data:#{mime};base64,#{data}")
          end
          result = @policy.apply(html)
          Body.new(kind: :html, content: result.html, base_url: nil,
            attachments: message.attachments.map(&:filename).compact, headers: {"blocked_count" => result.blocked_count})
        elsif (part = message.text_part)
          Body.new(kind: :text, content: message.decoded(part), base_url: nil,
            attachments: message.attachments.map(&:filename).compact, headers: {})
        else
          Body.new(kind: :text, content: "", base_url: nil, attachments: [], headers: {})
        end
      end

      def supports?(capability)
        %i[refresh search unread].include?(capability)
      end
    end
  end
end
