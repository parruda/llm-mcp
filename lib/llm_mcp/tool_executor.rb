# frozen_string_literal: true

module LlmMcp
  # Handles tool execution for both FastMCP serving and RubyLLM integration
  class ToolExecutor
    extend Forwardable

    def_delegators :@logger, :log_tool_call, :log_tool_response

    def initialize(mcp_client:, logger:)
      @mcp_client = mcp_client
      @logger = logger
      @tool_cache = {}
    end

    # Create a RubyLLM-compatible tool object
    def create_llm_tool(tool_info)
      tool_name = tool_info.respond_to?(:name) ? tool_info.name : tool_info[:name]

      # Return cached tool if available
      return @tool_cache[tool_name] if @tool_cache[tool_name]

      # Create tool struct that RubyLLM can use
      tool_struct = Struct.new(:name, :description, :parameters) do
        attr_reader :executor, :tool_info

        def initialize(name, description, parameters, executor, tool_info)
          super(name, description, parameters)
          @executor = executor
          @tool_info = tool_info
        end

        def call(args = {})
          # Handle both positional and keyword arguments
          args = {} unless args.is_a?(Hash)
          tool_name = @tool_info.respond_to?(:name) ? @tool_info.name : @tool_info[:name]
          @executor.execute_tool(tool_name, args)
        end
      end

      # Convert schema to parameters
      schema = if tool_info.respond_to?(:schema)
        tool_info.schema
      else
        tool_info[:inputSchema] || tool_info[:schema]
      end
      parameters = convert_schema_to_parameters(schema)

      # Create and cache the tool
      description = if tool_info.respond_to?(:description)
        tool_info.description || "MCP tool: #{tool_name}"
      else
        tool_info[:description] || "MCP tool: #{tool_name}"
      end

      @tool_cache[tool_name] = tool_struct.new(
        tool_name,
        description,
        parameters,
        self,
        tool_info,
      )
    end

    # Execute a tool call (used by RubyLLM tools)
    def execute_tool(tool_name, args)
      log_tool_call(
        tool_name: tool_name,
        arguments: args,
        provider: "mcp_via_llm",
      )

      begin
        # Call the MCP tool
        result = @mcp_client.call_tool(tool_name, args)

        # Log the response
        log_tool_response(
          tool_name: tool_name,
          response: result,
        )

        # Format for RubyLLM
        format_llm_response(result)
      rescue StandardError => e
        error_message = "Error calling MCP tool '#{tool_name}': #{e.message}"

        # Log the error
        log_tool_response(
          tool_name: tool_name,
          response: { error: error_message },
          error: e.message,
        )

        error_message
      end
    end

    private

    def convert_schema_to_parameters(schema)
      return {} unless schema.is_a?(Hash) && schema[:properties]

      required = Array(schema[:required])
      schema[:properties].each_with_object({}) do |(name, prop), parameters|
        param_name = name.to_s
        parameters[param_name] = RubyLLM::Parameter.new(
          param_name,
          type: prop[:type] || "string",
          desc: prop[:description] || "",
          required: required.include?(param_name) || required.include?(name),
        )
      end
    end

    def format_llm_response(result)
      # Extract the actual content from JSON-RPC response
      if result.is_a?(Hash)
        if result[:error]
          "Error: #{result[:error][:message] || result[:error]}"
        elsif result[:result]
          extract_text_content(result[:result])
        else
          extract_text_content(result)
        end
      else
        result.to_s
      end
    end

    def extract_text_content(content)
      case content
      when Array
        # MCP content array format
        if content.all? { |item| item.is_a?(Hash) && item[:type] }
          content.map { |item| item[:text] || item.to_s }.join("\n")
        else
          JSON.pretty_generate(content)
        end
      when Hash
        if content[:type] && content[:text]
          content[:text]
        elsif content[:content]
          extract_text_content(content[:content])
        else
          JSON.pretty_generate(content)
        end
      when String
        content
      else
        content.to_s
      end
    end
  end
end
