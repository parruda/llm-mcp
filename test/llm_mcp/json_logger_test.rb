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
    @logger.log(event_type: "test", data: { message: "Hello" })

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    # Check top-level structure
    assert_equal("test_instance", log_entry["instance"])
    assert_equal("test_123", log_entry["instance_id"])
    assert_equal("caller", log_entry["calling_instance"])
    assert_equal("caller_456", log_entry["calling_instance_id"])
    assert(log_entry["timestamp"])

    # Check event structure
    assert_equal("test", log_entry["event"]["type"])
    assert_equal("Hello", log_entry["event"]["message"])
    assert(log_entry["event"]["timestamp"])
  end

  def test_logs_request
    @logger.log_request(
      provider: "openai",
      model: "gpt-4",
      messages: [{ role: "user", content: "Test" }],
      temperature: 0.7,
    )

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    # Check event structure
    assert_equal("request", log_entry["event"]["type"])
    assert_equal("Test", log_entry["event"]["prompt"])
    assert_equal("caller", log_entry["event"]["from_instance"])
    assert_equal("caller_456", log_entry["event"]["from_instance_id"])
    assert_equal("test_instance", log_entry["event"]["to_instance"])
    assert_equal("test_123", log_entry["event"]["to_instance_id"])
    assert_equal("openai", log_entry["event"]["provider"])
    assert_equal("gpt-4", log_entry["event"]["model"])
    assert_in_delta(0.7, log_entry["event"]["temperature"])
  end

  def test_logs_response
    @logger.log_response(
      provider: "openai",
      model: "gpt-4",
      response: "Test response",
      tokens: { input: 10, output: 20 },
    )

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    assert_equal("assistant", log_entry["event"]["type"])
    assert_equal("assistant", log_entry["event"]["message"]["role"])
    assert_equal("gpt-4", log_entry["event"]["message"]["model"])
    assert_equal("text", log_entry["event"]["message"]["content"][0]["type"])
    assert_equal("Test response", log_entry["event"]["message"]["content"][0]["text"])
    assert_equal({ "input" => 10, "output" => 20 }, log_entry["event"]["message"]["usage"])
  end

  def test_logs_tool_call
    @logger.log_tool_call(
      tool_name: "Task",
      arguments: { prompt: "Hello" },
    )

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    assert_equal("tool_use", log_entry["event"]["type"])
    assert_equal("Task", log_entry["event"]["tool"])
    assert_equal("Task", log_entry["event"]["tool_name"])
    assert_equal({ "prompt" => "Hello" }, log_entry["event"]["arguments"])
  end

  def test_logs_tool_response
    @logger.log_tool_response(
      tool_name: "Task",
      response: { content: "Response" },
    )

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    assert_equal("tool_result", log_entry["event"]["type"])
    assert_equal("Task", log_entry["event"]["tool"])
    assert_equal("Task", log_entry["event"]["tool_name"])
    assert_equal({ "content" => "Response" }, log_entry["event"]["response"])
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

  def test_creates_log_directory_if_missing
    temp_dir = Dir.mktmpdir
    log_path = File.join(temp_dir, "subdir", "test.jsonl")

    logger = LlmMcp::JsonLogger.new(log_path, @instance_info)
    logger.log(event_type: "test", data: {})

    assert_path_exists(log_path)
    assert(File.directory?(File.dirname(log_path)))

    FileUtils.rm_rf(temp_dir)
  end
end
