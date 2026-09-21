# frozen_string_literal: true

require_relative "test_helper"

class DubheTest < Minitest::Test
  RSS = <<~XML
    <rss version="2.0"><channel><title>Example</title><link>https://example.test/</link>
      <item><guid>one</guid><title>One</title><link>/one</link><description><![CDATA[<p>Hello <strong>reader</strong>.</p><img src="https://tracker.test/p.gif">]]></description><pubDate>Tue, 21 Sep 2026 10:00:00 GMT</pubDate></item>
    </channel></rss>
  XML

  def test_policy_blocks_remote_images_and_rejects_path_escape
    policy = Dubhe::Policy.new
    result = policy.apply('<p onclick="x"><img src="https://tracker.test/p.gif"><a href="javascript:alert(1)">x</a></p>')

    assert_equal 1, result.blocked_count
    refute_includes result.html, "javascript"
    refute_includes result.html, "onclick"
    assert_includes result.html, "data-blocked-src"
    Dir.mktmpdir do |root|
      File.write(File.join(root, "ok.html"), "ok")
      assert_equal File.realpath(File.join(root, "ok.html")), policy.resolve_local(root, "ok.html")
      assert_raises(Dubhe::Policy::Denied) { policy.resolve_local(root, "../outside") }
    end
  end

  def test_store_is_append_only_and_replays_state
    Dir.mktmpdir do |root|
      store = Dubhe::Store.new(root: root)
      entry = Dubhe::Entry.new(id: "id", source_id: "feeds", title: "Title", author: nil,
        published_at: Time.utc(2026, 9, 21), updated_at: nil, url: "https://example.test",
        summary: "summary", tags: ["ruby"], state: :unread, parent_id: nil)
      store.save_entry(entry)
      store.update_state("id", state: :read, tags: ["ruby", "seen"])
      body = Dubhe::Body.new(kind: :html, content: "<p>body</p>", base_url: nil, attachments: [], headers: {})
      store.save_body("id", body)

      loaded = store.entries.first
      assert_equal :read, loaded.state
      assert_equal ["ruby", "seen"], loaded.tags
      assert_equal "<p>body</p>", store.body("id").content
    end
  end

  def test_feeds_refreshes_entries_saves_body_and_sends_conditional_headers
    Dir.mktmpdir do |root|
      fetcher = FakeFetcher.new(RSS, headers: {"etag" => "v1", "last-modified" => "yesterday"})
      source = Dubhe::Sources::Feeds.new(store: Dubhe::Store.new(root: root), fetcher: fetcher)
      subscription = source.add("https://example.test/feed.xml")
      entries = source.refresh(force: true)

      assert_equal subscription.id, source.subscriptions.first.id
      assert_equal 1, entries.length
      assert_equal "One", entries.first.title
      assert_equal 1, source.entries.length
      assert_includes source.fetch_body(entries.first).content, "Hello"
      source.refresh(force: true)
      assert_equal "v1", fetcher.requests.last[1]["If-None-Match"]
    end
  end

  def test_feed_subscriptions_survive_reinitialization
    Dir.mktmpdir do |root|
      store = Dubhe::Store.new(root: root)
      source = Dubhe::Sources::Feeds.new(store: store)
      subscription = source.add("https://example.test/feed.xml", title: "Example")

      reloaded = Dubhe::Sources::Feeds.new(store: Dubhe::Store.new(root: root))

      assert_equal [{id: subscription.id, title: "Example"}],
        reloaded.subscriptions.map { |value| {id: value.id, title: value.title} }
    end
  end

  def test_feed_discovery_and_reader_history
    links = Dubhe::Sources::Feeds.discover('<link rel="alternate" type="application/atom+xml" href="/feed.atom">', base_url: "https://example.test/page")
    assert_equal ["https://example.test/feed.atom"], links

    source = Struct.new(:id) do
      def entries(filter: nil) = []
      def fetch_body(_entry) = Dubhe::Body.new(kind: :text, content: "body", base_url: nil, attachments: [], headers: {})
    end.new("source")
    reader = Dubhe::Reader.new(sources: [source], store: Dubhe::Store.new(root: Dir.mktmpdir))
    assert_nil reader.back
  end

  def test_sources_advertise_the_capabilities_they_implement
    Dir.mktmpdir do |directory|
      docs = Dubhe::Sources::Docs.new(root: directory,
        store: Dubhe::Store.new(root: File.join(directory, "store")))
      mail = Dubhe::Sources::Mail.new(path: File.join(directory, "message.eml"),
        store: Dubhe::Store.new(root: File.join(directory, "mail-store")))

      assert docs.supports?(:refresh)
      assert mail.supports?(:refresh)
    end
  end

  def test_renderer_accepts_rows_with_different_lengths
    document = Jabbah.parse("<table><tr><td>a</td><td>b</td></tr><tr><td>c</td></tr></table>")

    rendered = Dubhe::Render.call(document)

    assert_includes rendered, "| a | b |"
    assert_includes rendered, "| c |   |"
  end
end
