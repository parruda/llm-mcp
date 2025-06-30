# frozen_string_literal: true

module LlmMcp
  class JsonLogger
    def initialize(log_path, instance_info = {})
      @logger = Logger.new(log_path, level: :info, formatter: proc { |_severity, datetime, _progname, msg|
        iso_time = datetime.iso8601
        msg[:event][:timestamp] = iso_time
        msg[:timestamp] = iso_time

        JSON.generate(msg) << "\n"
      })
      @instance_info = instance_info
    end

    def log(event_type:, data:)
      # Build the top-level structure with instance info
      entry = {
        instance: @instance_info[:name],
        instance_id: @instance_info[:instance_id],
        calling_instance: @instance_info[:calling_instance],
        calling_instance_id: @instance_info[:calling_instance_id],
        event: {
          type: event_type,
        }.merge(data),
      }.compact # Remove nil values

      @logger.info { entry }
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
  end
end
