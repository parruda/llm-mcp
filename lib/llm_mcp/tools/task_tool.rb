# frozen_string_literal: true

module LlmMcp
  module Tools
    class TaskTool < FastMcp::Tool
      extend Forwardable

      def_delegators :context, :chat, :session_manager, :logger, :provider, :model

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

      def call(prompt:, temperature: nil, max_tokens: nil)
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

        if context[:reasoning_effort] && context[:provider] == "openai" && ["o3", "o3-pro", "o4-mini-high", "o4-mini"].include?(context[:model])
          reasoning_effort = context[:reasoning_effort]
          chat_with_history = chat_with_history.with_options(reasoning_effort: reasoning_effort)
        end

        # Log request
        logger.log_request(
          provider: provider,
          model: model,
          messages: session_manager.to_chat_messages,
          temperature: temperature,
          max_tokens: max_tokens,
        )

        # Get response
        response = chat_with_history.ask(prompt)

        # Add assistant message to session
        session_manager.add_message(
          role: "assistant",
          content: response.content,
          input_tokens: response.input_tokens,
          output_tokens: response.output_tokens,
        )

        # Log response
        logger.log_response(
          provider: provider,
          model: model,
          response: response.content,
          tokens: {
            input: response.input_tokens,
            output: response.output_tokens,
          },
        )

        # Return MCP-compliant response format
        {
          content: [
            {
              type: "text",
              text: response.content,
            },
          ],
          _meta: {
            tokens: {
              input: response.input_tokens,
              output: response.output_tokens,
            },
            model: response.model_id,
          },
        }
      rescue StandardError => e
        error_message = "Error calling LLM: #{e.message}"
        logger.log(
          event_type: "error",
          data: { error: error_message, backtrace: e.backtrace },
        )
        {
          content: [
            {
              type: "text",
              text: error_message,
            },
          ],
          isError: true,
        }
      end
    end
  end
end
