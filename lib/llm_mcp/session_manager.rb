# frozen_string_literal: true

require "json"
require "fileutils"
require "time"

module LlmMcp
  class SessionManager
    DEFAULT_SESSION_PATH = File.expand_path("~/.llm-mcp/sessions")

    attr_reader :session_id, :session_path, :messages

    def initialize(session_id: nil, session_path: nil)
      @session_path = session_path || DEFAULT_SESSION_PATH
      @session_id = session_id || generate_session_id
      @messages = []
      @session_file = File.join(@session_path, "#{@session_id}.json")

      ensure_session_directory
      load_or_create_session
    end

    def add_message(role:, content:, **metadata)
      message = {
        role: role,
        content: content,
        timestamp: Time.now.iso8601
      }.merge(metadata)

      @messages << message
      save_session
      message
    end

    def clear
      @messages = []
      save_session
    end

    def to_chat_messages
      @messages.select { |m| %w[system user assistant].include?(m[:role]) }
               .map { |m| { role: m[:role], content: m[:content] } }
    end

    private

    def generate_session_id
      Time.now.strftime("%Y%m%d_%H%M%S")
    end

    def ensure_session_directory
      FileUtils.mkdir_p(@session_path)
    end

    def load_or_create_session
      if File.exist?(@session_file)
        load_session
      else
        create_session
      end
    end

    def load_session
      data = JSON.parse(File.read(@session_file), symbolize_names: true)
      @messages = data[:messages] || []
      @session_id = data[:session_id] || @session_id
    rescue JSON::ParserError => e
      warn "Warning: Failed to parse session file: #{e.message}"
      create_session
    end

    def create_session
      save_session
    end

    def save_session
      data = {
        session_id: @session_id,
        created_at: @messages.empty? ? Time.now.iso8601 : @messages.first[:timestamp],
        updated_at: Time.now.iso8601,
        messages: @messages
      }

      File.write(@session_file, JSON.pretty_generate(data))
    end
  end
end
