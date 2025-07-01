# frozen_string_literal: true

require "test_helper"

# Simple stub class for session manager
class StubSessionManager
  attr_reader :calls

  def initialize(messages_to_return = [])
    @calls = []
    @messages_to_return = messages_to_return
  end

  def add_message(role:, content:, **metadata)
    @calls << [:add_message, { role: role, content: content }.merge(metadata)]
  end

  def to_chat_messages
    @calls << [:to_chat_messages]
    @messages_to_return
  end
end

# Simple stub class for JSON logger
class StubJsonLogger
  attr_reader :calls

  def initialize
    @calls = []
  end

  def log_request(**kwargs)
    @calls << [:log_request, kwargs]
  end

  def log_response(**kwargs)
    @calls << [:log_response, kwargs]
  end

  def log(**kwargs)
    @calls << [:log, kwargs]
  end
end

class TaskToolTest < Minitest::Test
  def setup
    @chat = Minitest::Mock.new
    @response = Minitest::Mock.new
  end

  def create_tool_with_stubs(messages = [])
    @session_manager = StubSessionManager.new(messages)
    @json_logger = StubJsonLogger.new

    context = LlmMcp::Context.new(
      chat: @chat,
      session_manager: @session_manager,
      logger: @json_logger,
      provider: "openai",
      model: "gpt-4",
    )

    # Set context on the class
    LlmMcp::Tools::TaskTool.context = context
    @tool = LlmMcp::Tools::TaskTool.new(headers: {})
  end

  def test_call_success
    prompt = "Hello, world!"
    messages = [{ role: "user", content: prompt }]
    create_tool_with_stubs(messages)

    chat_copy = Minitest::Mock.new
    @chat.expect(:dup, chat_copy)
    chat_copy.expect(:add_message, nil) do |*_args, **kwargs|
      kwargs == { role: "user", content: prompt }
    end
    chat_copy.expect(:ask, @response, [prompt])

    # Response methods are called multiple times
    # For adding to session
    # For logging
    # # For result
    3.times do
      @response.expect(:content, "Hello! How can I help you?")
      @response.expect(:input_tokens, 10)
      @response.expect(:output_tokens, 20)
    end
    @response.expect(:model_id, "gpt-4") # For result

    result = @tool.call(prompt: prompt)

    expected_result = {
      content: [{
        type: "text",
        text: "Hello! How can I help you?",
      }],
      _meta: {
        tokens: {
          input: 10,
          output: 20,
        },
        model: "gpt-4",
      },
    }

    assert_equal(expected_result, result)

    # Verify session manager calls
    expected_calls = [
      [:add_message, { role: "user", content: prompt }],
      [:to_chat_messages],
      [:to_chat_messages], # Called twice - once for history, once for logging
      [:add_message, { role: "assistant", content: "Hello! How can I help you?", input_tokens: 10, output_tokens: 20 }],
    ]

    assert_equal(expected_calls, @session_manager.calls)

    # Verify logger calls
    assert_equal([:log_request, :log_response], @json_logger.calls.map(&:first))

    @chat.verify
    @response.verify
  end

  def test_call_with_temperature_from_context
    prompt = "Generate code"
    temperature = 0.2

    # Add temperature to context
    context = LlmMcp::Context.new(
      chat: @chat,
      session_manager: StubSessionManager.new([]),
      logger: StubJsonLogger.new,
      provider: "openai",
      model: "gpt-4",
      temperature: temperature,
    )
    LlmMcp::Tools::TaskTool.context = context
    @tool = LlmMcp::Tools::TaskTool.new(headers: {})
    @session_manager = context.session_manager
    @json_logger = context.logger

    chat_copy = Minitest::Mock.new
    chat_with_temp = Minitest::Mock.new

    @chat.expect(:dup, chat_copy)
    # No messages to add since to_chat_messages returns empty array
    chat_copy.expect(:with_temperature, chat_with_temp, [temperature])
    chat_with_temp.expect(:ask, @response, [prompt])

    3.times do
      @response.expect(:content, "Generated code")
      @response.expect(:input_tokens, 15)
      @response.expect(:output_tokens, 50)
    end
    @response.expect(:model_id, "gpt-4")

    result = @tool.call(prompt: prompt)
    expected_result = {
      content: [{
        type: "text",
        text: "Generated code",
      }],
      _meta: {
        tokens: {
          input: 15,
          output: 50,
        },
        model: "gpt-4",
      },
    }

    assert_equal(expected_result, result)

    # Verify temperature was passed to logger
    log_request = @json_logger.calls.find { |c| c[0] == :log_request }

    assert_equal(temperature, log_request[1][:temperature])

    @chat.verify
    @response.verify
  end

  def test_call_without_chat_instance
    # Temporarily set context without chat
    original_context = LlmMcp::Tools::TaskTool.context
    LlmMcp::Tools::TaskTool.context = LlmMcp::Context.new(chat: nil)

    tool = LlmMcp::Tools::TaskTool.new(headers: {})
    result = tool.call(prompt: "Test")

    assert_equal("LLM chat instance not initialized", result[:error])

    # Restore original context
    LlmMcp::Tools::TaskTool.context = original_context
  end

  def test_call_handles_errors
    create_tool_with_stubs([])

    mock_error = Class.new(StandardError) do
      def backtrace
        ["Test backtrace"]
      end
    end

    # Make to_chat_messages raise an error
    @session_manager.define_singleton_method(:to_chat_messages) do
      @calls << [:to_chat_messages]
      raise mock_error, "Test error"
    end

    chat_copy = Minitest::Mock.new
    @chat.expect(:dup, chat_copy)

    result = @tool.call(prompt: "Test")

    expected_result = {
      content: [{
        type: "text",
        text: "Error calling LLM: Test error",
      }],
      isError: true,
    }

    assert_equal(expected_result, result)

    # Verify error was logged
    log_call = @json_logger.calls
    expected_log_call = [
      [
        :log,
        {
          event_type: "error",
          data: { error: "Error calling LLM: Test error", backtrace: ["Test backtrace"] },
        },
      ],
    ]

    assert_equal(expected_log_call, log_call)

    @chat.verify
  end

  def test_tool_description
    assert_equal("Send a request to the LLM and get a response", LlmMcp::Tools::TaskTool.description)
  end

  def test_tool_arguments
    schema = LlmMcp::Tools::TaskTool.input_schema_to_json

    expected_schema = {
      type: "object",
      required: ["prompt"],
      properties: {
        prompt: {
          type: "string",
          description: "The prompt to send to the LLM",
        },
      },
    }

    assert_equal(expected_schema, schema)
  end
end
