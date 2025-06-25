# frozen_string_literal: true

require "fast_mcp"

module LlmMcp
  module Tools
    class TaskTool < FastMcp::Tool
      tool_name "task"
      description "Send a request to the LLM and get a response"
      annotations(read_only_hint: true, open_world_hint: false, destructive_hint: false)

      arguments do
        required(:prompt).filled(:string).description("The prompt to send to the LLM")
      end

      class << self
        attr_accessor :context
      end

      def initialize(headers: {})
        @headers = headers
        super()
      end

      def context
        self.class.context
      end

      def authorized?(**_args)
        true
      end

      def call(prompt:)
        chat = context[:chat]
        session_manager = context[:session_manager]
        json_logger = context[:json_logger]

        return { error: "LLM chat instance not initialized" } unless chat

        # Add user message to session
        session_manager.add_message(role: "user", content: prompt)

        # Prepare chat with session history
        chat_with_history = chat.dup
        session_manager.to_chat_messages.each do |msg|
          chat_with_history.add_message(role: msg[:role], content: msg[:content])
        end

        # Apply temperature from context if configured
        temperature = context[:temperature]
        chat_with_history = chat_with_history.with_temperature(temperature) if temperature

        # Log request
        json_logger&.log_request(
          provider: context[:provider],
          model: context[:model],
          messages: session_manager.to_chat_messages,
          temperature: temperature
        )

        # Get response
        response = chat_with_history.ask(prompt)

        # Add assistant message to session
        session_manager.add_message(
          role: "assistant",
          content: response.content,
          input_tokens: response.input_tokens,
          output_tokens: response.output_tokens
        )

        # Log response
        json_logger&.log_response(
          provider: context[:provider],
          model: context[:model],
          response: response.content,
          tokens: {
            input: response.input_tokens,
            output: response.output_tokens
          }
        )

        # Return MCP-compliant response format
        {
          content: [
            {
              type: "text",
              text: response.content
            }
          ],
          _meta: {
            tokens: {
              input: response.input_tokens,
              output: response.output_tokens
            },
            model: response.model_id
          }
        }
      rescue StandardError => e
        error_message = "Error calling LLM: #{e.message}"
        json_logger&.log(
          event_type: "error",
          data: { error: error_message, backtrace: e.backtrace }
        )
        {
          content: [
            {
              type: "text",
              text: error_message
            }
          ],
          isError: true
        }
      end
    end
  end
end
