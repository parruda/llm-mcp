# frozen_string_literal: true

require "test_helper"

class SessionManagerTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @session_manager = LlmMcp::SessionManager.new(
      session_id: "test_session",
      session_path: @temp_dir
    )
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_initializes_with_custom_session_id
    assert_equal "test_session", @session_manager.session_id
  end

  def test_generates_session_id_if_not_provided
    manager = LlmMcp::SessionManager.new(session_path: @temp_dir)

    assert_match(/\d{8}_\d{6}/, manager.session_id)
  end

  def test_creates_session_directory
    assert File.directory?(@temp_dir)
  end

  def test_adds_messages
    message = @session_manager.add_message(
      role: "user",
      content: "Hello"
    )

    assert_equal "user", message[:role]
    assert_equal "Hello", message[:content]
    assert message[:timestamp]
    assert_equal 1, @session_manager.messages.length
  end

  def test_saves_and_loads_session
    @session_manager.add_message(role: "user", content: "Test message")

    # Create new manager with same session ID
    new_manager = LlmMcp::SessionManager.new(
      session_id: "test_session",
      session_path: @temp_dir
    )

    assert_equal 1, new_manager.messages.length
    assert_equal "Test message", new_manager.messages.first[:content]
  end

  def test_clears_messages
    @session_manager.add_message(role: "user", content: "Message 1")
    @session_manager.add_message(role: "assistant", content: "Message 2")

    @session_manager.clear

    assert_empty @session_manager.messages
  end

  def test_converts_to_chat_messages
    @session_manager.add_message(role: "system", content: "System prompt")
    @session_manager.add_message(role: "user", content: "User message")
    @session_manager.add_message(role: "assistant", content: "Assistant response")
    @session_manager.add_message(role: "metadata", content: "Should be filtered")

    chat_messages = @session_manager.to_chat_messages

    assert_equal 3, chat_messages.length
    assert_equal(%w[system user assistant], chat_messages.map { |m| m[:role] })
  end

  def test_handles_corrupted_session_file
    session_file = File.join(@temp_dir, "test_session.json")
    File.write(session_file, "invalid json")

    manager = LlmMcp::SessionManager.new(
      session_id: "test_session",
      session_path: @temp_dir
    )

    assert_empty manager.messages
  end
end
