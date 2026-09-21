# Dubhe

Dubhe (α Ursae Majoris, from Arabic *dubb*, “bear”) is a feeds-first reader
core for static documents, RSS/Atom/JSON Feed subscriptions, and local mail.
It does not execute JavaScript, embed a WebView, or send mail.

## Features

- File-backed append-only entry/state indexes and content bodies
- RSS, Atom, and JSON Feed subscriptions through Iklil
- Conditional HTTP requests with ETag/Last-Modified and bounded redirects
- Safe HTML policy through Jabbah: XSS removal and remote-image blocking
- Feed discovery and OPML import/export
- Local HTML/Markdown docs with root-confined path resolution
- Ukdah-backed `.eml`/`.mbox` source API with CID image replacement
- Small reader/history/search API and plain-text reader-mode rendering

## Installation

```ruby
gem "dubhe"
```

```sh
gem install dubhe
```

Dubhe requires Ruby 3.2 or newer. It uses Iklil, Jabbah, and Ukdah for
parsing, while HTTP and persistence use Ruby's standard library.

## Quick start

```ruby
require "dubhe"

store = Dubhe::Store.new
feeds = Dubhe::Sources::Feeds.new(store: store)
feeds.add("https://example.test/feed.xml")
feeds.refresh

feeds.entries.each { |entry| puts entry.title }
```

Use `Dubhe::Policy` before displaying arbitrary HTML. Remote images are
blocked by default and `Result#blocked_count` is intended for a visible notice
in the UI. Dubhe is a reader core; a terminal or GPU view is an application
concern.

## Development

```sh
bundle install
bundle exec rake test
```

## License

Dubhe is released under the [MIT License](LICENSE.txt).
