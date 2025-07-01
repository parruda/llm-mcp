# frozen_string_literal: true

module LlmMcp
  class McpConfigLoader
    class << self
      def load_and_create_client(config_path)
        return unless config_path && File.exist?(config_path)

        config = JSON.parse(File.read(config_path), symbolize_names: true)
        server_configs = config[:mcpServers]&.filter_map do |server_name, server_config|
          convert_to_mcp_client_config(server_name, server_config)
        end

        # Create single client with all server configurations
        return if server_configs.empty?

        MCPClient.create_client(mcp_server_configs: server_configs)
      rescue JSON::ParserError => e
        warn("Failed to parse MCP config: #{e.message}")
        nil
      rescue StandardError => e
        warn("Failed to create MCP client: #{e.message}")
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
            env: config[:env] || {},
          )
        elsif config[:url]
          mcp_config = {
            name: server_name.to_s,
            base_url: config[:url],
            headers: config[:headers] || {},
          }

          # Determine transport type based on URL or config
          if config[:transport] == "sse" || config[:url].include?("/sse")
            MCPClient.sse_config(**mcp_config)
          else
            MCPClient.http_config(**mcp_config)
          end
        else
          warn("Invalid config for #{server_name}: missing url or command")
          nil
        end
      rescue StandardError => e
        warn("Failed to convert config for #{server_name}: #{e.message}")
        nil
      end
    end
  end
end
