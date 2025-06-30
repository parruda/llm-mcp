# frozen_string_literal: true

require "test_helper"

class SessionManagerTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @session_manager = LlmMcp::SessionManager.new(
      session_id: "test_session",
      session_path: @temp_dir,
    )
  end

  def teardown
    FileUtils.remove_entry(@temp_dir)
  end

  def test_initializes_with_custom_session_id
    assert_equal("test_session", @session_manager.session_id)
  end

  def test_generates_session_id_if_not_provided
    manager = LlmMcp::SessionManager.new(session_path: @temp_dir)

    assert_match(/\d{8}_\d{6}/, manager.session_id)
  end

  def test_creates_session_directory
    assert(File.directory?(@temp_dir))
  end

  def test_adds_messages
    current_time = nil
    current_message = nil
    Timecop.freeze do
      current_time = Time.now.iso8601
      current_message = @session_manager.add_message(
        role: "user",
        content: "Hello",
      )
    end

    expected_message = {
      role: "user",
      content: "Hello",
      timestamp: current_time,
    }

    assert_equal(expected_message, current_message)
    assert_equal(1, @session_manager.messages.length)
  end

  def test_saves_and_loads_session
    @session_manager.add_message(role: "user", content: "Test message")

    # Create new manager with same session ID
    new_manager = LlmMcp::SessionManager.new(
      session_id: "test_session",
      session_path: @temp_dir,
    )

    assert_equal(1, new_manager.messages.length)
    assert_equal("Test message", new_manager.messages.first[:content])
  end

  def test_clears_messages
    @session_manager.add_message(role: "user", content: "Message 1")
    @session_manager.add_message(role: "assistant", content: "Message 2")

    @session_manager.clear

    assert_empty(@session_manager.messages)
  end

  def test_converts_to_chat_messages
    @session_manager.add_message(role: "system", content: "System prompt")
    @session_manager.add_message(role: "user", content: "User message")
    @session_manager.add_message(role: "assistant", content: "Assistant response")
    @session_manager.add_message(role: "metadata", content: "Should be filtered")

    chat_messages = @session_manager.to_chat_messages

    assert_equal(3, chat_messages.length)
    assert_equal(["system", "user", "assistant"], chat_messages.map { |m| m[:role] })
  end

  def test_handles_corrupted_session_file
    session_file = File.join(@temp_dir, "test_session.json")
    File.write(session_file, "invalid json")

    manager = nil
    capture_io do
      manager = LlmMcp::SessionManager.new(
        session_id: "test_session",
        session_path: @temp_dir,
      )
    end

    assert_empty(manager.messages)
  end
end
