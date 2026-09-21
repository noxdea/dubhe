# frozen_string_literal: true

require "digest"
require "cgi/escape"
require "pathname"
require "uri"
require "jabbah"

module Dubhe
  module Sources
    class Docs
      include Source

      EXTENSIONS = %w[.html .htm .md .markdown].freeze

      attr_reader :root

      def initialize(root:, store: Store.new, policy: Policy.new(profile: :docs))
        @root = File.expand_path(root.to_s)
        @store = store
        @policy = policy
      end

      def id = "docs:#{Digest::SHA256.hexdigest(@root)}"
      def title = File.basename(@root)
      def icon = "folder"

      def refresh
        entries = files.map do |path|
          relative = Pathname.new(path).relative_path_from(Pathname.new(@root)).to_s
          Entry.new(id: "#{id}:#{relative}", source_id: id, title: title_for(path), author: nil,
            published_at: nil, updated_at: File.mtime(path), url: "file://#{path}", summary: nil,
            tags: [], state: :unread, parent_id: parent_id(relative))
        end
        entries.each { |entry| @store.save_entry(entry); @store.save_body(entry.id, fetch_body(entry)) }
        entries
      end

      def entries(filter: nil)
        result = @store.entries(source_id: id)
        result = refresh if result.empty?
        filter ? result.select { |entry| filter.call(entry) } : result
      end

      def fetch_body(entry)
        path = resolve(entry.url.to_s.sub("file://", ""))
        if markdown?(path)
          Body.new(kind: :html, content: markdown_to_html(File.read(path)), base_url: "file://#{path}", attachments: [], headers: {})
        else
          result = @policy.apply(File.binread(path), base_url: nil)
          Body.new(kind: :html, content: result.html, base_url: "file://#{path}", attachments: [], headers: {"blocked_count" => result.blocked_count})
        end
      end

      def resolve(path)
        candidate = path.to_s.start_with?("file://") ? path.to_s.sub("file://", "") : path
        @policy.resolve_local(@root, candidate)
      end

      def supports?(capability)
        %i[search tree unread].include?(capability)
      end

      private

      def files
        Dir.glob(File.join(@root, "**", "*")).select do |path|
          File.file?(path) && EXTENSIONS.include?(File.extname(path).downcase) &&
            path.split(File::SEPARATOR).none? { |part| part.start_with?(".") || %w[node_modules vendor].include?(part) }
        end.sort
      end

      def markdown?(path)
        %w[.md .markdown].include?(File.extname(path).downcase)
      end

      def title_for(path)
        return File.basename(path, File.extname(path)) unless markdown?(path)

        first_heading = File.foreach(path).find { |line| line.match?(/\A#\s+/) }
        first_heading ? first_heading.sub(/\A#\s+/, "").strip : File.basename(path, File.extname(path))
      end

      def parent_id(relative)
        directory = File.dirname(relative)
        return nil if directory == "."

        "#{id}:#{directory}"
      end

      def markdown_to_html(text)
        lines = text.to_s.lines
        output = []
        paragraph = []
        flush = lambda do
          output << "<p>#{paragraph.join(" ").strip}</p>" unless paragraph.empty?
          paragraph.clear
        end
        in_code = false
        code = []
        lines.each do |line|
          if line.start_with?("```")
            if in_code
              output << "<pre><code>#{CGI.escapeHTML(code.join)}</code></pre>"
              code.clear
            end
            in_code = !in_code
          elsif in_code
            code << line
          elsif line.match?(/\A#+\s+/)
            flush.call
            level = line[/\A#+/].length
            output << "<h#{level}>#{CGI.escapeHTML(line.sub(/\A#+\s+/, "").strip)}</h#{level}>"
          elsif line.strip.empty?
            flush.call
          else
            paragraph << CGI.escapeHTML(line.strip)
          end
        end
        in_code ? output << "<pre><code>#{CGI.escapeHTML(code.join)}</code></pre>" : flush.call
        output.join
      end
    end
  end
end
