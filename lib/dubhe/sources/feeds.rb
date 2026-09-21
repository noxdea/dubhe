# frozen_string_literal: true

require "digest"
require "time"
require "uri"
require "iklil"
require "jabbah"

module Dubhe
  module Sources
    class Feeds
      include Source

      attr_reader :last_errors

      def initialize(subscriptions: [], store: Store.new, fetcher: Fetch::Client.new,
                     policy: Policy.new(profile: :feed), interval: 3600, clock: -> { Time.now })
        @store = store
        @fetcher = fetcher
        @policy = policy
        @interval = interval
        @clock = clock
        @subscriptions = Array(subscriptions).map { |value| normalize_subscription(value) }
        @raw_entries = {}
        @last_errors = {}
      end

      def id = "feeds"
      def title = "Feeds"
      def icon = "rss"

      def add(url, title: nil, site_url: nil, group: nil)
        normalized = url.to_s.strip
        existing = @subscriptions.find { |subscription| subscription.url == normalized }
        return existing if existing

        subscription = Subscription.new(id: Digest::SHA256.hexdigest(normalized), title: title || normalized,
          url: normalized, site_url: site_url, group: group, etag: nil, last_modified: nil,
          interval: @interval, next_refresh_at: nil, failures: 0)
        @subscriptions << subscription
        subscription
      end

      def remove(id_or_url)
        before = @subscriptions.length
        @subscriptions.reject! { |subscription| subscription.id == id_or_url.to_s || subscription.url == id_or_url.to_s }
        before != @subscriptions.length
      end

      def subscriptions = @subscriptions.dup

      def refresh(force: false)
        refreshed = []
        now = @clock.call
        @subscriptions = @subscriptions.map do |subscription|
          next subscription if !force && subscription.next_refresh_at && subscription.next_refresh_at > now

          begin
            headers = {"If-None-Match" => subscription.etag, "If-Modified-Since" => subscription.last_modified}
            response = @fetcher.get(subscription.url, headers: headers)
            if response.status == 304
              refreshed.concat(@store.entries(source_id: id).select { |entry| entry.updated_at && entry.updated_at >= now - subscription.interval })
              next schedule(subscription, now: now, failures: 0)
            end
            raise Error, "feed returned HTTP #{response.status}" unless response.status.between?(200, 299)

            feed = Iklil.parse(response.body, base_url: subscription.url)
            entries = feed.entries.map do |raw_entry|
              entry = convert_entry(subscription, raw_entry)
              @raw_entries[entry.id] = raw_entry
              entry
            end
            entries.each do |entry|
              @store.save_entry(entry)
              @store.save_body(entry.id, fetch_body(entry))
            end
            refreshed.concat(entries)
            schedule(subscription, now: now, failures: 0, title: feed.title, site_url: feed.site_url,
              etag: response.headers["etag"], last_modified: response.headers["last-modified"])
          rescue StandardError => error
            @last_errors[subscription.id] = error
            schedule(subscription, now: now, failures: subscription.failures + 1)
          end
        end
        refreshed
      end

      def entries(filter: nil)
        result = @store.entries(source_id: id)
        return result unless filter

        result.select { |entry| filter.call(entry) }
      end

      def fetch_body(entry)
        source = @raw_entries[entry.id]
        if source.nil?
          stored = @store.body(entry.id)
          return stored if stored
          return Body.new(kind: :text, content: entry.summary.to_s, base_url: entry.url, attachments: [], headers: {})
        end
        content = source.content.to_s
        if source.html?
          result = @policy.apply(content, base_url: entry.url)
          extracted = Jabbah::Extract.article(result.document)
          content = extracted ? extracted[:content].to_html : result.html
          Body.new(kind: :html, content: content, base_url: entry.url, attachments: source.enclosures, headers: {"blocked_count" => result.blocked_count})
        else
          Body.new(kind: :text, content: content, base_url: entry.url, attachments: source.enclosures, headers: {})
        end
      end

      def supports?(capability)
        %i[refresh search unread].include?(capability)
      end

      def import_opml(bytes)
        Iklil.parse_opml(bytes).each { |subscription| add(subscription.xml_url, title: subscription.title, site_url: subscription.html_url) }
      end

      def export_opml(title: "Dubhe subscriptions")
        Iklil.render_opml(@subscriptions.map { |subscription| {title: subscription.title, xml_url: subscription.url,
          html_url: subscription.site_url, category: subscription.group} }, title: title)
      end

      def self.discover(html, base_url: nil)
        document = html.is_a?(Jabbah::Document) ? html : Jabbah.parse(html)
        document.search("link").filter_map do |link|
          rel = link["rel"].to_s.split.map(&:downcase)
          type = link["type"].to_s.downcase
          next unless rel.include?("alternate") && %w[application/rss+xml application/atom+xml application/feed+json application/json].include?(type)

          href = link["href"]
          next unless href && !href.empty?
          base_url ? URI.join(base_url, href).to_s : href
        rescue URI::InvalidURIError
          nil
        end.uniq
      end

      private

      def normalize_subscription(value)
        return value if value.is_a?(Subscription)

        url = value[:url] || value["url"]
        title = value[:title] || value["title"] || url
        Subscription.new(id: Digest::SHA256.hexdigest(url.to_s), title: title, url: url.to_s,
          site_url: value[:site_url] || value["site_url"], group: value[:group] || value["group"],
          etag: value[:etag] || value["etag"], last_modified: value[:last_modified] || value["last_modified"],
          interval: value[:interval] || value["interval"] || @interval,
          next_refresh_at: value[:next_refresh_at] || value["next_refresh_at"],
          failures: value[:failures] || value["failures"] || 0)
      end

      def convert_entry(subscription, entry)
        Entry.new(id: "#{subscription.id}:#{entry.id}", source_id: id, title: entry.title.to_s,
          author: Array(entry.authors).join(", "), published_at: entry.published_at, updated_at: entry.updated_at,
          url: entry.url, summary: entry.summary.to_s, tags: Array(entry.categories), state: :unread, parent_id: nil)
      end

      def schedule(subscription, now:, failures:, title: subscription.title, site_url: subscription.site_url,
                   etag: subscription.etag, last_modified: subscription.last_modified)
        delay = failures.zero? ? subscription.interval : [300 * (3**(failures - 1)), 21_600].min
        Subscription.new(id: subscription.id, title: title || subscription.title, url: subscription.url,
          site_url: site_url, group: subscription.group, etag: etag, last_modified: last_modified,
          interval: subscription.interval, next_refresh_at: now + delay, failures: failures)
      end
    end
  end
end
