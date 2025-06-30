# frozen_string_literal: true

module LlmMcp
  class JsonLogger
    def initialize(log_path, instance_info = {})
      @log_path = log_path
      @mutex = Concurrent::ReentrantReadWriteLock.new
      @instance_info = instance_info

      ensure_log_directory
    end

    def log(event_type:, data:)
      timestamp = Time.now.iso8601

      # Build the top-level structure with instance info
      entry = {
        instance: @instance_info[:name],
        instance_id: @instance_info[:instance_id],
        calling_instance: @instance_info[:calling_instance],
        calling_instance_id: @instance_info[:calling_instance_id],
        timestamp: timestamp,
        event: {
          type: event_type,
          timestamp: timestamp,
        }.merge(data),
      }.compact # Remove nil values

      write_log(entry)
    end

    def log_request(provider:, model:, messages:, **metadata)
      # Extract the last message as the prompt
      prompt = messages.last[:content] if messages.any?

      log(
        event_type: "request",
        data: {
          from_instance: @instance_info[:calling_instance],
          from_instance_id: @instance_info[:calling_instance_id],
          to_instance: @instance_info[:name],
          to_instance_id: @instance_info[:instance_id],
          prompt: prompt,
          provider: provider,
          model: model,
          messages: messages,
        }.merge(metadata).compact,
      )
    end

    def log_response(provider:, model:, response:, tokens: nil, **metadata)
      log(
        event_type: "assistant",
        data: {
          message: {
            role: "assistant",
            model: model,
            content: [{ type: "text", text: response }],
            usage: tokens,
          },
          provider: provider,
          response: response,
          tokens: tokens,
        }.merge(metadata).compact,
      )
    end

    def log_tool_call(tool_name:, arguments:, **metadata)
      log(
        event_type: "tool_use",
        data: {
          tool: tool_name,
          tool_name: tool_name,
          arguments: arguments,
        }.merge(metadata).compact,
      )
    end

    def log_tool_response(tool_name:, response:, **metadata)
      log(
        event_type: "tool_result",
        data: {
          tool: tool_name,
          tool_name: tool_name,
          response: response,
        }.merge(metadata).compact,
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
      warn("Failed to write to log: #{e.message}")
    end
  end
end
