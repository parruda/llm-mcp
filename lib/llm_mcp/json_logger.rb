# frozen_string_literal: true

require "json"
require "concurrent"
require "fileutils"

module LlmMcp
  class JsonLogger
    def initialize(log_path)
      @log_path = log_path
      @mutex = Concurrent::ReentrantReadWriteLock.new

      ensure_log_directory
    end

    def log(event_type:, data:)
      entry = {
        timestamp: Time.now.iso8601,
        event_type: event_type,
        data: data
      }

      write_log(entry)
    end

    def log_request(provider:, model:, messages:, **metadata)
      log(
        event_type: "llm_request",
        data: {
          provider: provider,
          model: model,
          messages: messages
        }.merge(metadata)
      )
    end

    def log_response(provider:, model:, response:, tokens: nil, **metadata)
      log(
        event_type: "llm_response",
        data: {
          provider: provider,
          model: model,
          response: response,
          tokens: tokens
        }.merge(metadata)
      )
    end

    def log_tool_call(tool_name:, arguments:, **metadata)
      log(
        event_type: "tool_call",
        data: {
          tool_name: tool_name,
          arguments: arguments
        }.merge(metadata)
      )
    end

    def log_tool_response(tool_name:, response:, **metadata)
      log(
        event_type: "tool_response",
        data: {
          tool_name: tool_name,
          response: response
        }.merge(metadata)
      )
    end

    private

    def ensure_log_directory
      return unless @log_path

      dir = File.dirname(@log_path)
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
    end

    def write_log(entry)
      return unless @log_path

      @mutex.with_write_lock do
        File.open(@log_path, "a") do |file|
          file.flock(File::LOCK_EX)
          file.puts(JSON.generate(entry))
          file.flock(File::LOCK_UN)
        end
      end
    rescue StandardError => e
      warn "Failed to write to log: #{e.message}"
    end
  end
end
