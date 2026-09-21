# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "time"

module Dubhe
  class Store
    attr_reader :root

    def initialize(root: nil)
      data_root = root || ENV["XDG_DATA_HOME"] || File.join(Dir.home, ".local", "share")
      @root = root ? File.expand_path(root.to_s) : File.join(data_root.to_s, "dubhe")
      @index_root = File.join(@root, "index")
      @body_root = File.join(@root, "bodies")
      FileUtils.mkdir_p([@index_root, @body_root])
    end

    def save_entry(entry)
      append("entries.jsonl", serialize_entry(entry))
      entry
    end

    def save_entries(entries)
      Array(entries).each { |entry| save_entry(entry) }
      entries
    end

    def entries(source_id: nil)
      records = read_jsonl("entries.jsonl")
      latest = {}
      records.each { |record| latest[record["id"].to_s] = record }
      states = state_records
      latest.values.filter_map do |record|
        next if source_id && record["source_id"] != source_id

        deserialize_entry(record, states[record["id"].to_s])
      end
    end

    def entry(id)
      entries.find { |item| item.id == id.to_s }
    end

    def update_state(id, state: nil, starred: nil, tags: nil)
      current = state_records[id.to_s] || {}
      record = {"id" => id.to_s, "state" => (state || current["state"] || "unread"),
        "starred" => starred.nil? ? current["starred"] : starred,
        "tags" => tags.nil? ? current["tags"] : tags}
      append("state.jsonl", record)
      record
    end

    def save_body(id, body)
      digest = Digest::SHA256.hexdigest(id.to_s)
      directory = File.join(@body_root, digest[0, 2], digest[2, 2])
      FileUtils.mkdir_p(directory)
      path = File.join(directory, "#{digest}.#{extension(body.kind)}")
      temporary = "#{path}.tmp-#{Process.pid}-#{rand(1_000_000)}"
      File.binwrite(temporary, body.content.to_s)
      File.rename(temporary, path)
      path
    ensure
      File.delete(temporary) if temporary && File.file?(temporary)
    end

    def body(id)
      digest = Digest::SHA256.hexdigest(id.to_s)
      directory = File.join(@body_root, digest[0, 2], digest[2, 2])
      path = %w[html text markdown].map { |kind| File.join(directory, "#{digest}.#{kind}") }.find { |candidate| File.file?(candidate) }
      return nil unless path

      kind = File.extname(path).delete_prefix(".").to_sym
      Body.new(kind: kind, content: File.binread(path), base_url: nil, attachments: [], headers: {})
    end

    def compact!
      rewrite("entries.jsonl", entries.map { |entry| serialize_entry(entry) })
      rewrite("state.jsonl", state_records.values)
      self
    end

    private

    def append(name, record)
      File.open(File.join(@index_root, name), "ab") { |file| file.write(JSON.generate(record) << "\n") }
    end

    def read_jsonl(name)
      path = File.join(@index_root, name)
      return [] unless File.file?(path)

      File.foreach(path).filter_map do |line|
        JSON.parse(line)
      rescue JSON::ParserError
        nil
      end
    end

    def state_records
      read_jsonl("state.jsonl").each_with_object({}) { |record, result| result[record["id"].to_s] = record }
    end

    def serialize_entry(entry)
      {"id" => entry.id.to_s, "source_id" => entry.source_id.to_s, "title" => entry.title,
        "author" => entry.author, "published_at" => encode_time(entry.published_at),
        "updated_at" => encode_time(entry.updated_at), "url" => entry.url, "summary" => entry.summary,
        "tags" => Array(entry.tags), "state" => entry.state.to_s, "parent_id" => entry.parent_id}
    end

    def deserialize_entry(record, state)
      merged = record.merge(state || {})
      Entry.new(id: record["id"], source_id: record["source_id"], title: record["title"],
        author: record["author"], published_at: decode_time(record["published_at"]),
        updated_at: decode_time(record["updated_at"]), url: record["url"], summary: record["summary"],
        tags: Array(merged["tags"]), state: (merged["state"] || "unread").to_sym, parent_id: record["parent_id"])
    end

    def encode_time(value)
      value&.iso8601
    end

    def decode_time(value)
      Time.parse(value.to_s) if value && !value.to_s.empty?
    rescue ArgumentError
      nil
    end

    def extension(kind)
      %i[html text markdown].include?(kind.to_sym) ? kind.to_s : "text"
    end

    def rewrite(name, records)
      path = File.join(@index_root, name)
      temporary = "#{path}.tmp-#{Process.pid}"
      File.open(temporary, "wb") { |file| records.each { |record| file.write(JSON.generate(record) << "\n") } }
      File.rename(temporary, path)
    ensure
      File.delete(temporary) if temporary && File.file?(temporary)
    end
  end
end
