# frozen_string_literal: true

require "test_helper"

class McpConfigLoaderTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_loads_stdio_config
    config = {
      mcpServers: {
        filesystem: {
          command: "npx",
          args: ["@modelcontextprotocol/server-filesystem", "/tmp"],
          env: { "DEBUG" => "true" },
        },
      },
    }

    config_file = File.join(@temp_dir, "mcp_config.json")
    File.write(config_file, JSON.generate(config))

    fake_client = Object.new

    MCPClient.stub(:create_client, fake_client) do
      client = LlmMcp::McpConfigLoader.load_and_create_client(config_file)

      assert_equal(fake_client, client)
    end
  end

  def test_loads_sse_config
    config = {
      mcpServers: {
        weather: {
          url: "https://weather-mcp.example.com/sse",
          transport: "sse",
          headers: { "Authorization" => "Bearer token" },
        },
      },
    }

    config_file = File.join(@temp_dir, "mcp_config.json")
    File.write(config_file, JSON.generate(config))

    fake_client = Object.new

    MCPClient.stub(:create_client, fake_client) do
      client = LlmMcp::McpConfigLoader.load_and_create_client(config_file)

      assert_equal(fake_client, client)
    end
  end

  def test_handles_multiple_servers
    config = {
      mcpServers: {
        server1: { command: "cmd1" },
        server2: { url: "https://example.com" },
      },
    }

    config_file = File.join(@temp_dir, "mcp_config.json")
    File.write(config_file, JSON.generate(config))

    fake_client = Object.new

    # MCPClient.create_client should be called once with configs for all servers
    MCPClient.stub(:create_client, fake_client) do
      client = LlmMcp::McpConfigLoader.load_and_create_client(config_file)

      assert_equal(fake_client, client)
    end
  end

  def test_handles_missing_config_file
    capture_io do
      assert_nil(LlmMcp::McpConfigLoader.load_and_create_client("/non/existent/file.json"))
    end
  end

  def test_handles_invalid_json
    config_file = File.join(@temp_dir, "invalid.json")
    File.write(config_file, "invalid json content")

    capture_io do
      assert_nil(LlmMcp::McpConfigLoader.load_and_create_client(config_file))
    end
  end

  def test_skips_invalid_server_configs
    config = {
      mcpServers: {
        valid: { command: "cmd" },
        invalid: { neither_command_nor_url: true },
      },
    }

    config_file = File.join(@temp_dir, "mcp_config.json")
    File.write(config_file, JSON.generate(config))

    fake_client = Object.new

    capture_io do
      # Should still create client with only valid configs
      MCPClient.stub(:create_client, fake_client) do
        assert_equal(fake_client, LlmMcp::McpConfigLoader.load_and_create_client(config_file))
      end
    end
  end

  def test_empty_server_config_returns_nil
    config = {
      mcpServers: {},
    }

    config_file = File.join(@temp_dir, "mcp_config.json")
    File.write(config_file, JSON.generate(config))

    capture_io do
      assert_nil(LlmMcp::McpConfigLoader.load_and_create_client(config_file))
    end
  end

  def test_all_invalid_servers_returns_nil
    config = {
      mcpServers: {
        invalid1: { neither_command_nor_url: true },
        invalid2: { also_invalid: true },
      },
    }

    config_file = File.join(@temp_dir, "mcp_config.json")
    File.write(config_file, JSON.generate(config))

    capture_io do
      assert_nil(LlmMcp::McpConfigLoader.load_and_create_client(config_file))
    end
  end
end
