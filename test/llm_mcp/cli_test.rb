# frozen_string_literal: true

require "test_helper"
require "stringio"

class CLITest < Minitest::Test
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new
  end

  def teardown
    $stderr = @original_stderr
  end

  def test_mcp_serve_requires_provider
    # Capture stderr to check the error message
    captured_stderr = StringIO.new
    original_stderr = $stderr
    $stderr = captured_stderr

    assert_raises(SystemExit) do
      LlmMcp::CLI.start(["mcp-serve", "--model", "gpt-4"])
    end

    $stderr = original_stderr

    assert_match(/No value provided for required options '--provider'/, captured_stderr.string)
  end

  def test_mcp_serve_requires_model
    # Capture stderr to check the error message
    captured_stderr = StringIO.new
    original_stderr = $stderr
    $stderr = captured_stderr

    assert_raises(SystemExit) do
      LlmMcp::CLI.start(["mcp-serve", "--provider", "openai"])
    end

    $stderr = original_stderr

    assert_match(/No value provided for required options '--model'/, captured_stderr.string)
  end

  def test_version_command
    output = capture_io do
      LlmMcp::CLI.start(["version"])
    end

    assert_match(/llm-mcp \d+\.\d+\.\d+/, output.first)
  end

  def test_mcp_serve_with_all_options
    mock_server = Minitest::Mock.new
    mock_server.expect :start, nil

    LlmMcp::Server.stub :new, mock_server do
      LlmMcp::CLI.start([
                          "mcp-serve",
                          "--provider", "openai",
                          "--model", "gpt-4",
                          "--base-url", "https://custom.openai.com",
                          "--append-system-prompt", "Be helpful",
                          "--verbose",
                          "--json-log-path", "/tmp/log.jsonl",
                          "--mcp-config", "/tmp/mcp.json",
                          "--session-id", "custom_session",
                          "--session-path", "/tmp/sessions"
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

    LlmMcp::Server.stub :new, mock_server do
      exit_raised = false
      begin
        LlmMcp::CLI.start([
                            "mcp-serve",
                            "--provider", "openai",
                            "--model", "gpt-4"
                          ])
      rescue SystemExit => e
        exit_raised = true

        assert_equal 1, e.status
      end

      assert exit_raised, "Expected SystemExit to be raised"
    end

    error_output = $stderr.string

    assert_match(/Error: Test error/, error_output)
  end

  def test_mcp_serve_shows_backtrace_in_verbose_mode
    # Mock server that raises error on start
    mock_server = Object.new
    def mock_server.start
      raise StandardError, "Test error"
    end

    LlmMcp::Server.stub :new, mock_server do
      exit_raised = false
      begin
        LlmMcp::CLI.start([
                            "mcp-serve",
                            "--provider", "openai",
                            "--model", "gpt-4",
                            "--verbose"
                          ])
      rescue SystemExit => e
        exit_raised = true

        assert_equal 1, e.status
      end

      assert exit_raised, "Expected SystemExit to be raised"
    end

    error_output = $stderr.string

    assert_match(/Test error/, error_output)
    assert_match(/test_mcp_serve_shows_backtrace/, error_output) # Should show backtrace
  end
end
