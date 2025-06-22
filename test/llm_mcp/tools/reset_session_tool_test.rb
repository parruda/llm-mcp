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

    @context = {
      session_manager: @session_manager,
      json_logger: @json_logger
    }

    # Set context on the class
    LlmMcp::Tools::ResetSessionTool.context = @context
    @tool = LlmMcp::Tools::ResetSessionTool.new(headers: {})
  end

  def test_call_success
    result = @tool.call

    assert_equal 1, result[:content].length
    assert_equal "text", result[:content][0][:type]
    assert_equal "Session has been reset. The conversation history has been cleared.", result[:content][0][:text]

    # Verify session was cleared
    assert_includes @session_manager.calls, [:clear]

    # Verify log was called
    log_call = @json_logger.calls.find { |c| c[0] == :log && c[1][:event_type] == "session_reset" }

    assert log_call
    assert_equal "test_session_123", log_call[1][:data][:session_id]
    assert_equal 5, log_call[1][:data][:previous_message_count]
  end

  def test_call_without_session_manager
    # Temporarily set context without session manager
    original_context = LlmMcp::Tools::ResetSessionTool.context
    LlmMcp::Tools::ResetSessionTool.context = { session_manager: nil }

    tool = LlmMcp::Tools::ResetSessionTool.new(headers: {})
    result = tool.call

    assert_equal "Session manager not initialized", result[:error]

    # Restore original context
    LlmMcp::Tools::ResetSessionTool.context = original_context
  end

  def test_call_handles_errors
    # Make session_id raise an error
    @session_manager.define_singleton_method(:session_id) do
      raise StandardError, "Test error"
    end

    result = @tool.call

    assert_equal 1, result[:content].length
    assert_equal "text", result[:content][0][:type]
    assert_equal "Error resetting session: Test error", result[:content][0][:text]
    assert result[:isError]

    # Verify error was logged
    log_call = @json_logger.calls.find { |c| c[0] == :log && c[1][:event_type] == "error" }

    assert log_call
    assert_equal "Error resetting session: Test error", log_call[1][:data][:error]
  end

  def test_tool_description
    assert_equal "Clear the conversation context and start fresh", LlmMcp::Tools::ResetSessionTool.description
  end

  def test_tool_has_no_required_arguments
    schema = LlmMcp::Tools::ResetSessionTool.input_schema_to_json

    assert_empty schema[:required] || []
    assert_empty(schema[:properties] || {})
  end
end
