<h1 align="center">Dubhe</h1>

<p align="center"><strong>A feeds-first Ruby reader core for subscriptions, local documents, and mail.</strong></p>

<p align="center">
  <a href="https://rubygems.org/gems/dubhe"><img src="https://img.shields.io/gem/v/dubhe" alt="Gem version"></a>
  <a href="https://github.com/noxdea/dubhe/actions/workflows/main.yml"><img src="https://github.com/noxdea/dubhe/actions/workflows/main.yml/badge.svg" alt="CI status"></a>
  <img src="https://img.shields.io/badge/Ruby-3.2%2B-cc342d" alt="Ruby 3.2 or newer">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#feeds-and-mail">Feeds and mail</a> ·
  <a href="#safety-and-scope">Safety and scope</a>
</p>

---

Dubhe gives reader applications a persistent source and navigation layer.
It combines RSS, Atom, and JSON Feed subscriptions with local HTML/Markdown
documents and `.eml`/`.mbox` mail. It does not provide a UI or execute
JavaScript. The name comes from α Ursae Majoris and the Arabic *dubb*,
“bear.”

## Features

- File-backed entry/state indexes and content bodies
- Feed subscriptions with conditional HTTP requests and bounded redirects
- OPML import/export and feed discovery
- Local document sources with root-confined path resolution
- Mail sources backed by Ukdah, including CID image replacement
- Reader history, search, read/star state, and plain-text rendering

## Installation

Add `gem "dubhe"` to your Gemfile and run `bundle install`, or install directly:

```sh
gem install dubhe
```

Requires Ruby 3.2 or newer. Iklil, Jabbah, and Ukdah provide its parsing
and sanitization layers.

## Quick start

Index a directory of local `.md` and `.html` files:

```ruby
require "dubhe"

store = Dubhe::Store.new
docs = Dubhe::Sources::Docs.new(root: "notes", store: store)
reader = Dubhe::Reader.new(sources: [docs], store: store)

reader.refresh
reader.entries.each { |entry| puts entry.title }
```

Create `notes/` and add a Markdown or HTML file before running the example.
Without an explicit `root:`, the store uses the user's XDG data directory.

## Feeds and mail

Add a feed URL supplied by your application, then refresh it:

```ruby
feeds = Dubhe::Sources::Feeds.new(store: store)
feeds.add("https://your-feed.example/feed.xml")
feeds.refresh
feeds.entries.each { |entry| puts entry.title }
```

`feeds.last_errors` records refresh failures per subscription. Feeds use
ETag and Last-Modified for conditional requests; subscriptions can be
imported and exported as OPML. For local mail, use
`Dubhe::Sources::Mail.new(path: "archive.mbox", store: store)`.

`Dubhe::Reader` can combine these source objects, open an entry, navigate
back/forward, search, and persist read or starred state.

## Safety and scope

Use `Dubhe::Policy` before displaying arbitrary HTML. It sanitizes unsafe
markup and blocks remote images by default; surface `blocked_count` to
readers so they know images were omitted. Local paths are confined to the
configured documents root. Dubhe is a reader core, not a browser, WebView,
or mail transport. See [supported reader-mode elements](docs/supported-elements.md)
and the [reader-core boundary](docs/adr/001-reader-core-boundaries.md).

## Development

```sh
bundle install
bundle exec rake test
```

## License

[MIT](LICENSE.txt)
