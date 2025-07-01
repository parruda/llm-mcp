# frozen_string_literal: true

require "test_helper"

class ServerIntegrationTest < Minitest::Test
  def test_server_initialization
    config = {
      provider: "openai",
      model: "gpt-4",
      verbose: false,
    }

    # Mock the provider factory to avoid requiring API keys
    mock_chat = Minitest::Mock.new
    LlmMcp::ProviderFactory.stub(:create, mock_chat) do
      server = LlmMcp::Server.new(config)

      assert_instance_of(LlmMcp::Server, server)
    end
  end

  def test_cli_version
    output = %x(bundle exec exe/llm-mcp version 2>&1).strip

    assert_match(/llm-mcp \d+\.\d+\.\d+/, output)
  end
end
