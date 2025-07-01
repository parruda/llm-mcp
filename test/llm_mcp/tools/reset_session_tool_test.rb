# frozen_string_literal: true

require "test_helper"

# Simple stub class for session manager
class StubSessionManagerForReset
  attr_reader :calls, :session_id, :messages

  def initialize
    @calls = []
    @session_id = "test_session_123"
    @messages = Array.new(5) # 5 messages
  end

  def clear
    @calls << [:clear]
    @messages = []
  end
end

# Simple stub class for JSON logger
class StubJsonLoggerForReset
  attr_reader :calls

  def initialize
    @calls = []
  end

  def log(**kwargs)
    @calls << [:log, kwargs]
  end
end

class ResetSessionToolTest < Minitest::Test
  def setup
    @session_manager = StubSessionManagerForReset.new
    @json_logger = StubJsonLoggerForReset.new

    @context = LlmMcp::Context.new(session_manager: @session_manager, logger: @json_logger)

    # Set context on the class
    LlmMcp::Tools::ResetSessionTool.context = @context
    @tool = LlmMcp::Tools::ResetSessionTool.new(headers: {})
  end

  def test_call_success
    result = @tool.call

    expected_result = {
      content: [{
        type: "text",
        text: "Session has been reset. The conversation history has been cleared.",
      }],
    }

    assert_equal(expected_result, result)

    # Verify session was cleared
    assert_includes(@session_manager.calls, [:clear])

    # Verify log was called
    log_call = @json_logger.calls
    expected_log_call =
      [
        [
          :log,
          {
            event_type: "session_reset",
            data: {
              session_id: "test_session_123",
              previous_message_count: 5,
            },
          },
        ],
      ]

    assert_equal(expected_log_call, log_call)
  end

  def test_call_without_session_manager
    # Temporarily set context without session manager
    original_context = LlmMcp::Tools::ResetSessionTool.context
    LlmMcp::Tools::ResetSessionTool.context = LlmMcp::Context.new(session_manager: nil)

    tool = LlmMcp::Tools::ResetSessionTool.new(headers: {})
    result = tool.call

    assert_equal("Session manager not initialized", result[:error])

    # Restore original context
    LlmMcp::Tools::ResetSessionTool.context = original_context
  end

  def test_call_handles_errors
    mock_error = Class.new(StandardError) do
      def backtrace
        ["Test backtrace"]
      end
    end
    # Make session_id raise an error
    @session_manager.define_singleton_method(:session_id) do
      raise mock_error, "Test error"
    end

    result = @tool.call
    expected_result = {
      content: [{
        type: "text",
        text: "Error resetting session: Test error",
      }],
      isError: true,
    }

    assert_equal(expected_result, result)

    # Verify error was logged
    expected_log_call = [
      [
        :log,
        {
          event_type: "error",
          data: { error: "Error resetting session: Test error", backtrace: ["Test backtrace"] },
        },
      ],
    ]

    assert_equal(expected_log_call, @json_logger.calls)
  end

  def test_tool_description
    assert_equal("Clear the conversation context and start fresh", LlmMcp::Tools::ResetSessionTool.description)
  end

  def test_tool_has_no_required_arguments
    schema = LlmMcp::Tools::ResetSessionTool.input_schema_to_json

    assert_empty(schema[:required] || [])
    assert_empty(schema[:properties] || {})
  end
end
