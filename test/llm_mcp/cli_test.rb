# frozen_string_literal: true

require "test_helper"

class CLITest < Minitest::Test
  def test_mcp_serve_requires_provider
    _, err = capture_io do
      assert_raises(SystemExit) do
        LlmMcp::CLI.start(["mcp-serve", "--model", "gpt-4"])
      end
    end

    assert_match(/No value provided for required options '--provider'/, err)
  end

  def test_mcp_serve_requires_model
    _, err = capture_io do
      assert_raises(SystemExit) do
        LlmMcp::CLI.start(["mcp-serve", "--provider", "openai"])
      end
    end

    assert_match(/No value provided for required options '--model'/, err)
  end

  def test_version_command
    out, = capture_io do
      LlmMcp::CLI.start(["version"])
    end

    assert_match(/llm-mcp \d+\.\d+\.\d+/, out)
  end

  def test_mcp_serve_with_all_options
    mock_server = Minitest::Mock.new
    mock_server.expect(:start, nil)

    LlmMcp::Server.stub(:new, mock_server) do
      LlmMcp::CLI.start([
        "mcp-serve",
        "--provider",
        "openai",
        "--model",
        "gpt-4",
        "--base-url",
        "https://custom.openai.com",
        "--append-system-prompt",
        "Be helpful",
        "--verbose",
        "--json-log-path",
        "/tmp/log.jsonl",
        "--mcp-config",
        "/tmp/mcp.json",
        "--session-id",
        "custom_session",
        "--session-path",
        "/tmp/sessions",
      ])
    rescue SystemExit
      # Server.start will exit, which is expected
    end

    mock_server.verify
  end

  def test_mcp_serve_handles_errors
    # Mock server that raises error on start
    mock_server = Object.new
    def mock_server.start
      raise StandardError, "Test error"
    end

    _, err = capture_io do
      LlmMcp::Server.stub(:new, mock_server) do
        exit_raised = false
        begin
          LlmMcp::CLI.start([
            "mcp-serve",
            "--provider",
            "openai",
            "--model",
            "gpt-4",
          ])
        rescue SystemExit => e
          exit_raised = true

          assert_equal(1, e.status)
        end

        assert(exit_raised, "Expected SystemExit to be raised")
      end
    end

    assert_match(/Error: Test error/, err)
  end

  def test_mcp_serve_shows_backtrace_in_verbose_mode
    # Mock server that raises error on start
    mock_server = Object.new
    def mock_server.start
      raise StandardError, "Test error"
    end

    _, err = capture_io do
      LlmMcp::Server.stub(:new, mock_server) do
        exit_raised = false
        begin
          LlmMcp::CLI.start([
            "mcp-serve",
            "--provider",
            "openai",
            "--model",
            "gpt-4",
            "--verbose",
          ])
        rescue SystemExit => e
          exit_raised = true

          assert_equal(1, e.status)
        end

        assert(exit_raised, "Expected SystemExit to be raised")
      end
    end

    assert_match(/Test error/, err)
    assert_match(/test_mcp_serve_shows_backtrace/, err) # Should show backtrace
  end
end
