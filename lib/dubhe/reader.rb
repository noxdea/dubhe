# frozen_string_literal: true

module Dubhe
  class Reader
    attr_reader :sources, :current_entry

    def initialize(sources: [], store: Store.new)
      @store = store
      @sources = Array(sources)
      @history = []
      @history_index = -1
      @current_entry = nil
    end

    def add_source(source)
      @sources << source
      source
    end

    def refresh
      @sources.flat_map(&:refresh)
    end

    def entries(source_id: nil, filter: nil)
      result = if source_id
                 @sources.find { |source| source.id == source_id }&.entries(filter: filter) || []
               else
                 @sources.flat_map { |source| source.entries(filter: filter) }
               end
      result.sort_by { |entry| entry.updated_at || entry.published_at || Time.at(0) }.reverse
    end

    def open(entry)
      source = @sources.find { |candidate| candidate.id == entry.source_id }
      raise Error, "source not found: #{entry.source_id}" unless source

      @current_entry = entry
      @history = @history[0..@history_index] if @history_index >= 0
      @history << entry
      @history_index = @history.length - 1
      source.fetch_body(entry)
    end

    def back
      return nil if @history_index <= 0

      @history_index -= 1
      @current_entry = @history[@history_index]
      body_for(@current_entry)
    end

    def forward
      return nil if @history_index >= @history.length - 1

      @history_index += 1
      @current_entry = @history[@history_index]
      body_for(@current_entry)
    end

    def mark_read(entry, read: true)
      @store.update_state(entry.id, state: read ? :read : :unread)
      entry
    end

    def star(entry, starred: true)
      @store.update_state(entry.id, state: starred ? :starred : :read)
      entry
    end

    def search(query, source_id: nil)
      needle = query.to_s.downcase
      entries(source_id: source_id).select do |entry|
        body = @store.body(entry.id)&.content.to_s
        [entry.title, entry.author, entry.summary, body].compact.join(" ").downcase.include?(needle)
      end
    end

    private

    def body_for(entry)
      source = @sources.find { |candidate| candidate.id == entry.source_id }
      source&.fetch_body(entry)
    end
  end
end
