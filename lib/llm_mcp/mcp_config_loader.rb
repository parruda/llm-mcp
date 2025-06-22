# frozen_string_literal: true

require "json"
# HACK: ruby-mcp-client gem has require path issues, using explicit path
$LOAD_PATH.unshift(File.expand_path("~/.gem/ruby/3.4.2/gems/ruby-mcp-client-0.7.1/lib"))
require "mcp_client"

module LlmMcp
  class McpConfigLoader
    class << self
      def load_and_create_client(config_path)
        return nil unless config_path && File.exist?(config_path)

        config = JSON.parse(File.read(config_path), symbolize_names: true)

        # Convert config to ruby-mcp-client format
        server_configs = []

        config[:mcpServers]&.each do |server_name, server_config|
          mcp_config = convert_to_mcp_client_config(server_name, server_config)
          server_configs << mcp_config if mcp_config
        end

        # Create single client with all server configurations
        return nil if server_configs.empty?

        MCPClient.create_client(mcp_server_configs: server_configs)
      rescue JSON::ParserError => e
        warn "Failed to parse MCP config: #{e.message}"
        nil
      rescue StandardError => e
        warn "Failed to create MCP client: #{e.message}"
        nil
      end

      private

      def convert_to_mcp_client_config(server_name, config)
        if config[:command]
          # STDIO transport
          # Combine command and args into a single array
          command = if config[:args] && !config[:args].empty?
                      [config[:command]] + config[:args]
                    else
                      config[:command]
                    end

          MCPClient.stdio_config(
            name: server_name.to_s,
            command: command,
            env: config[:env] || {}
          )
        elsif config[:url]
          # Determine transport type based on URL or config
          if config[:transport] == "sse" || config[:url].include?("/sse")
            MCPClient.sse_config(
              name: server_name.to_s,
              base_url: config[:url],
              headers: config[:headers] || {}
            )
          else
            MCPClient.http_config(
              name: server_name.to_s,
              base_url: config[:url],
              headers: config[:headers] || {}
            )
          end
        else
          warn "Invalid config for #{server_name}: missing url or command"
          nil
        end
      rescue StandardError => e
        warn "Failed to convert config for #{server_name}: #{e.message}"
        nil
      end
    end
  end
end
