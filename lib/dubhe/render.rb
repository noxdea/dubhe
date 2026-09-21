# frozen_string_literal: true

require "cgi/escape"

module Dubhe
  module Render
    # EXTRACTION CANDIDATE: document renderer
    # Canopus and hadar can share this once a second consumer needs it.
    HANDLERS = {
      "p" => :paragraph, "h1" => :heading, "h2" => :heading, "h3" => :heading,
      "h4" => :heading, "h5" => :heading, "h6" => :heading, "li" => :list_item,
      "blockquote" => :quote, "pre" => :code_block, "hr" => :rule,
      "br" => :break, "table" => :table, "figure" => :figure
    }.freeze
    BLOCKS = (HANDLERS.keys + %w[div section article main header footer ul ol dl dt dd figcaption]).freeze

    module_function

    def call(node, theme: {})
      root = node.respond_to?(:root) ? node.root : node
      render_node(root, theme).strip
    end

    def render_node(node, theme)
      return CGI.unescapeHTML(node.data.to_s) if node.text?
      return "" unless node.element?
      return "" if %w[script style iframe object embed form].include?(node.name)

      content = node.children.map { |child| render_node(child, theme) }.join
      case HANDLERS[node.name]
      when :heading then "\n#{content.strip}\n"
      when :paragraph then "\n#{content.strip}\n"
      when :list_item then "\n• #{content.strip}"
      when :quote then "\n#{content.lines.map { |line| "> #{line}" }.join}"
      when :code_block then "\n```\n#{node.text}\n```\n"
      when :rule then "\n────────\n"
      when :break then "\n"
      when :table then "\n#{render_table(node)}\n"
      when :figure then "\n#{content.strip}\n"
      else
        BLOCKS.include?(node.name) ? "\n#{content}\n" : content
      end
    end

    def render_table(node)
      rows = node.search("tr").map do |row|
        row.children.select { |child| child.element? && %w[td th].include?(child.name) }.map { |cell| cell.text.strip }
      end
      return "" if rows.empty?

      width_count = rows.map(&:length).max.to_i
      widths = (0...width_count).map { |index| rows.filter_map { |row| row[index]&.length }.max.to_i }
      rows.map do |row|
        values = (0...width_count).map { |index| row[index].to_s.ljust(widths[index]) }
        "| #{values.join(" | ")} |"
      end.join("\n")
    end
  end
end
