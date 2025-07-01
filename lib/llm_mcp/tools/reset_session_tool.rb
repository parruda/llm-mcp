# frozen_string_literal: true

module LlmMcp
  module Tools
    class ResetSessionTool < FastMcp::Tool
      extend Forwardable

      def_delegators :context, :logger, :session_manager

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
        return { error: "Session manager not initialized" } unless session_manager

        # Log the reset action
        logger.log(
          event_type: "session_reset",
          data: {
            session_id: session_manager.session_id,
            previous_message_count: session_manager.messages.length,
          },
        )

        # Clear the session
        session_manager.clear

        {
          content: [
            {
              type: "text",
              text: "Session has been reset. The conversation history has been cleared.",
            },
          ],
        }
      rescue StandardError => e
        error_message = "Error resetting session: #{e.message}"
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
