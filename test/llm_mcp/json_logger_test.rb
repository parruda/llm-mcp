# frozen_string_literal: true

require "test_helper"

class JsonLoggerTest < Minitest::Test
  def setup
    @temp_file = Tempfile.new(["test_log", ".jsonl"])
    @logger = LlmMcp::JsonLogger.new(@temp_file.path)
  end

  def teardown
    @temp_file.close
    @temp_file.unlink
  end

  def test_logs_basic_event
    @logger.log(event_type: "test", data: { message: "Hello" })

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    assert_equal "test", log_entry["event_type"]
    assert_equal "Hello", log_entry["data"]["message"]
    assert log_entry["timestamp"]
  end

  def test_logs_request
    @logger.log_request(
      provider: "openai",
      model: "gpt-4",
      messages: [{ role: "user", content: "Test" }],
      temperature: 0.7
    )

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    assert_equal "llm_request", log_entry["event_type"]
    assert_equal "openai", log_entry["data"]["provider"]
    assert_equal "gpt-4", log_entry["data"]["model"]
    assert_in_delta(0.7, log_entry["data"]["temperature"])
  end

  def test_logs_response
    @logger.log_response(
      provider: "openai",
      model: "gpt-4",
      response: "Test response",
      tokens: { input: 10, output: 20 }
    )

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    assert_equal "llm_response", log_entry["event_type"]
    assert_equal "Test response", log_entry["data"]["response"]
    assert_equal({ "input" => 10, "output" => 20 }, log_entry["data"]["tokens"])
  end

  def test_logs_tool_call
    @logger.log_tool_call(
      tool_name: "Task",
      arguments: { prompt: "Hello" }
    )

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    assert_equal "tool_call", log_entry["event_type"]
    assert_equal "Task", log_entry["data"]["tool_name"]
    assert_equal({ "prompt" => "Hello" }, log_entry["data"]["arguments"])
  end

  def test_logs_tool_response
    @logger.log_tool_response(
      tool_name: "Task",
      response: { content: "Response" }
    )

    log_content = File.read(@temp_file.path)
    log_entry = JSON.parse(log_content.strip)

    assert_equal "tool_response", log_entry["event_type"]
    assert_equal "Task", log_entry["data"]["tool_name"]
    assert_equal({ "content" => "Response" }, log_entry["data"]["response"])
  end

  def test_appends_to_existing_file
    @logger.log(event_type: "event1", data: { id: 1 })
    @logger.log(event_type: "event2", data: { id: 2 })

    lines = File.readlines(@temp_file.path)

    assert_equal 2, lines.length

    entry1 = JSON.parse(lines[0])
    entry2 = JSON.parse(lines[1])

    assert_equal "event1", entry1["event_type"]
    assert_equal "event2", entry2["event_type"]
  end

  def test_handles_nil_log_path
    logger = LlmMcp::JsonLogger.new(nil)
    # Should not raise error
    logger.log(event_type: "test", data: {})
  end

  def test_creates_log_directory_if_missing
    temp_dir = Dir.mktmpdir
    log_path = File.join(temp_dir, "subdir", "test.jsonl")

    logger = LlmMcp::JsonLogger.new(log_path)
    logger.log(event_type: "test", data: {})

    assert_path_exists log_path
    assert File.directory?(File.dirname(log_path))

    FileUtils.rm_rf(temp_dir)
  end
end
