# frozen_string_literal: true

require "fast_mcp"

module LlmMcp
  module Tools
    class ResetSessionTool < FastMcp::Tool
      tool_name "reset_session"
      description "Clear the conversation context and start fresh"

      arguments do
        # No arguments needed
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

      def call
        session_manager = context[:session_manager]
        json_logger = context[:json_logger]

        return { error: "Session manager not initialized" } unless session_manager

        # Log the reset action
        json_logger&.log(
          event_type: "session_reset",
          data: {
            session_id: session_manager.session_id,
            previous_message_count: session_manager.messages.length
          }
        )

        # Clear the session
        session_manager.clear

        {
          content: [
            {
              type: "text",
              text: "Session has been reset. The conversation history has been cleared."
            }
          ]
        }
      rescue StandardError => e
        error_message = "Error resetting session: #{e.message}"
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
