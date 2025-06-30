# frozen_string_literal: true

module LlmMcp
  # Dynamically creates FastMCP-compatible tool classes from MCP tool definitions
  class McpToolAdapter
    class << self
      def create_from_mcp_tool(tool_info, mcp_client, context)
        # Generate a unique class name - handle MCPClient::Tool objects
        tool_name = tool_info.respond_to?(:name) ? tool_info.name : tool_info[:name]
        class_name = "Mcp#{tool_name.split(/[^a-zA-Z0-9]/).map(&:capitalize).join}Tool"

        # Remove existing constant if it exists (for reloading)
        LlmMcp.send(:remove_const, class_name) if LlmMcp.const_defined?(class_name)

        # Create new tool class
        tool_class = Class.new(FastMcp::Tool) do
          extend Forwardable

          def_delegators :@context, :logger

          # Class-level configuration
          @tool_info = tool_info
          @mcp_client = mcp_client
          @context = context

          class << self
            attr_reader :tool_info, :mcp_client, :context

            def tool_name
              @tool_info.respond_to?(:name) ? @tool_info.name : @tool_info[:name]
            end

            def description
              if @tool_info.respond_to?(:description)
                @tool_info.description || "MCP tool: #{@tool_info.name}"
              else
                @tool_info[:description] || "MCP tool: #{@tool_info[:name]}"
              end
            end

            def input_schema_to_json
              # Use the schema directly from MCP tool info
              schema = if @tool_info.respond_to?(:schema)
                @tool_info.schema
              else
                @tool_info[:inputSchema] || @tool_info[:schema]
              end

              schema || {
                type: "object",
                properties: {},
                required: [],
              }
            end
          end

          # Instance methods
          def initialize(headers: {})
            @headers = headers
            super()
          end

          def authorized?(**_args)
            true
          end

          def call(**args)
            # Get references from class
            mcp_client = self.class.mcp_client
            tool_info = self.class.tool_info
            tool_name = tool_info.respond_to?(:name) ? tool_info.name : tool_info[:name]

            # Log the call if JSON logger is available
            logger.log_tool_call(
              tool_name: tool_name,
              arguments: args,
              provider: "mcp",
            )

            begin
              # Call the MCP tool
              result = mcp_client.call_tool(tool_name, args)

              # Log the response
              logger.log_tool_response(
                tool_name: tool_name,
                response: result,
              )

              # Format for FastMCP
              format_mcp_result(result)
            rescue StandardError => e
              error_response = {
                content: [
                  {
                    type: "text",
                    text: "Error calling MCP tool '#{tool_name}': #{e.message}",
                  },
                ],
                isError: true,
              }

              # Log the error
              logger.log_tool_response(
                tool_name: tool_name,
                response: error_response,
                error: e.message,
              )

              error_response
            end
          end

          private

          def format_mcp_result(result)
            # Handle JSON-RPC style responses from ruby-mcp-client
            if result.is_a?(Hash)
              if result[:error]
                # JSON-RPC error response
                {
                  content: [
                    {
                      type: "text",
                      text: "MCP Error: #{result[:error][:message] || result[:error]}",
                    },
                  ],
                  isError: true,
                }
              elsif result[:result]
                # JSON-RPC success response - extract the actual result
                format_content(result[:result])
              else
                # Direct result
                format_content(result)
              end
            else
              # String or other result
              {
                content: [
                  {
                    type: "text",
                    text: result.to_s,
                  },
                ],
              }
            end
          end

          def format_content(content)
            case content
            when Array
              # Check if it's already MCP content array format
              if content.all? { |item| item.is_a?(Hash) && item[:type] }
                { content: content }
              else
                # Convert array to text
                {
                  content: [
                    {
                      type: "text",
                      text: JSON.pretty_generate(content),
                    },
                  ],
                }
              end
            when Hash
              if content[:type] && content[:text]
                # Single content item
                { content: [content] }
              elsif content[:content]
                # Already has content key
                content
              else
                # Convert hash to JSON text
                {
                  content: [
                    {
                      type: "text",
                      text: JSON.pretty_generate(content),
                    },
                  ],
                }
              end
            when String
              {
                content: [
                  {
                    type: "text",
                    text: content,
                  },
                ],
              }
            else
              {
                content: [
                  {
                    type: "text",
                    text: content.to_s,
                  },
                ],
              }
            end
          end
        end

        # Set the constant in LlmMcp module
        LlmMcp.const_set(class_name, tool_class)

        tool_class
      end
    end
  end
end
