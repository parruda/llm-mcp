# frozen_string_literal: true

require "test_helper"

class JsonLoggerTest < Minitest::Test
  def setup
    @temp_file = Tempfile.new(["test_log", ".jsonl"])
    @instance_info = {
      name: "test_instance",
      instance_id: "test_123",
      calling_instance: "caller",
      calling_instance_id: "caller_456",
    }
    @logger = LlmMcp::JsonLogger.new(@temp_file.path, @instance_info)
  end

  def teardown
    @temp_file.close
    @temp_file.unlink
  end

  def test_logs_basic_event
    current_time = nil
    Timecop.freeze do
      current_time = Time.now.iso8601
      @logger.log(event_type: "test", data: { message: "Hello" })
    end

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    # Check the complete log structure (excluding dynamic timestamps)
    expected_entry = {
      "timestamp" => current_time,
      "instance" => "test_instance",
      "instance_id" => "test_123",
      "calling_instance" => "caller",
      "calling_instance_id" => "caller_456",
      "event" => {
        "type" => "test",
        "message" => "Hello",
        "timestamp" => current_time,
      },
    }

    assert_equal(expected_entry, log_entry)
  end

  def test_logs_request
    current_time = nil
    Timecop.freeze do
      current_time = Time.now.iso8601
      @logger.log_request(
        provider: "openai",
        model: "gpt-4",
        messages: [{ role: "user", content: "Test" }],
        temperature: 0.7,
      )
    end

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    # Check the complete log structure (excluding dynamic fields)
    expected_entry = {
      "timestamp" => current_time,
      "instance" => "test_instance",
      "instance_id" => "test_123",
      "calling_instance" => "caller",
      "calling_instance_id" => "caller_456",
      "event" => {
        "type" => "request",
        "temperature" => 0.7,
        "prompt" => "Test",
        "from_instance" => "caller",
        "from_instance_id" => "caller_456",
        "to_instance" => "test_instance",
        "to_instance_id" => "test_123",
        "provider" => "openai",
        "model" => "gpt-4",
        "messages" => [{ "role" => "user", "content" => "Test" }],
        "timestamp" => current_time,
      },
    }

    assert_equal(expected_entry, log_entry, highlight: true)
  end

  def test_logs_response
    current_time = nil
    Timecop.freeze do
      current_time = Time.now.iso8601
      @logger.log_response(
        provider: "openai",
        model: "gpt-4",
        response: "Test response",
        tokens: { input: 10, output: 20 },
      )
    end

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    # Check the complete log structure (excluding dynamic timestamps)
    expected_entry = {
      "timestamp" => current_time,
      "instance" => "test_instance",
      "instance_id" => "test_123",
      "calling_instance" => "caller",
      "calling_instance_id" => "caller_456",
      "event" => {
        "type" => "assistant",
        "message" => {
          "role" => "assistant",
          "model" => "gpt-4",
          "content" => [
            {
              "type" => "text",
              "text" => "Test response",
            },
          ],
          "usage" => { "input" => 10, "output" => 20 },
        },
        "provider" => "openai",
        "response" => "Test response",
        "tokens" => { "input" => 10, "output" => 20 },
        "timestamp" => current_time,
      },
    }

    assert_equal(expected_entry, log_entry)
  end

  def test_logs_tool_call
    current_time = nil
    Timecop.freeze do
      current_time = Time.now.iso8601
      @logger.log_tool_call(
        tool_name: "Task",
        arguments: { prompt: "Hello" },
      )
    end

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    # Check the complete log structure (excluding dynamic timestamps)
    expected_entry = {
      "timestamp" => current_time,
      "instance" => "test_instance",
      "instance_id" => "test_123",
      "calling_instance" => "caller",
      "calling_instance_id" => "caller_456",
      "event" => {
        "type" => "tool_use",
        "tool" => "Task",
        "tool_name" => "Task",
        "arguments" => { "prompt" => "Hello" },
        "timestamp" => current_time,
      },
    }

    assert_equal(expected_entry, log_entry)
  end

  def test_logs_tool_response
    current_time = nil
    Timecop.freeze do
      current_time = Time.now.iso8601
      @logger.log_tool_response(
        tool_name: "Task",
        response: { content: "Response" },
      )
    end

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    # Check the complete log structure (excluding dynamic timestamps)
    expected_entry = {
      "timestamp" => current_time,
      "instance" => "test_instance",
      "instance_id" => "test_123",
      "calling_instance" => "caller",
      "calling_instance_id" => "caller_456",
      "event" => {
        "type" => "tool_result",
        "tool" => "Task",
        "tool_name" => "Task",
        "response" => { "content" => "Response" },
        "timestamp" => current_time,
      },
    }

    assert_equal(expected_entry, log_entry)
  end

  def test_appends_to_existing_file
    @logger.log(event_type: "event1", data: { id: 1 })
    @logger.log(event_type: "event2", data: { id: 2 })

    lines = File.readlines(@temp_file.path)

    assert_equal(2, lines.length)

    entry1 = JSON.parse(lines[0])
    entry2 = JSON.parse(lines[1])

    assert_equal("event1", entry1["event"]["type"])
    assert_equal("event2", entry2["event"]["type"])
  end

  def test_handles_nil_log_path
    logger = LlmMcp::JsonLogger.new(nil, @instance_info)
    # Should not raise error
    logger.log(event_type: "test", data: {})
  end
end
