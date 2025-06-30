# frozen_string_literal: true

module LlmMcp
  class Server
    def initialize(config)
      @config = config
      @verbose = config[:verbose]
      setup_components
      @context = build_context
    end

    def start
      log_startup_info

      # Create FastMCP server
      server = FastMcp::Server.new(
        name: "llm-mcp",
        version: VERSION,
      )

      # Store context on built-in tool classes
      Tools::TaskTool.context = @context
      Tools::ResetSessionTool.context = @context

      # Register built-in tools
      server.register_tool(Tools::TaskTool)
      server.register_tool(Tools::ResetSessionTool)
      log("Registered built-in tools: task, reset_session")

      # NOTE: External MCP tools are only registered with the LLM, not exposed via FastMCP

      # Start the server
      log("Starting MCP server...")
      server.start
    rescue StandardError => e
      error("Failed to start server: #{e.message}")
      error(e.backtrace.join("\n")) if @verbose
      exit(1)
    end

    private

    def setup_components
      # Enable role preservation if skip_model_validation is set
      if @config[:skip_model_validation]
        LlmMcp::RolePreservation.preserve_roles = true
        log("Role preservation enabled (skip_model_validation is set)")
      end

      # Initialize session manager
      @session_manager = SessionManager.new(**@config.slice(:session_id, :session_path))
      log("Session initialized: #{@session_manager.session_id}")

      # Initialize JSON logger with instance info
      instance_info = {
        name: @config[:name],
        instance_id: @config[:instance_id],
        calling_instance: @config[:calling_instance],
        calling_instance_id: @config[:calling_instance_id],
      }
      @json_logger = @config[:json_log_path] ? JsonLogger.new(@config[:json_log_path], instance_info) : nil
      log("JSON logging: #{@json_logger ? "enabled" : "disabled"}")

      # Initialize LLM chat
      @chat = ProviderFactory.create(**@config.slice(:provider, :model, :base_url, :append_system_prompt, :skip_model_validation))
      log("LLM initialized: #{@config[:provider]}/#{@config[:model]}")

      # Initialize MCP client and tools
      setup_mcp_integration
    end

    def setup_mcp_integration
      return unless @config[:mcp_config]

      # Load MCP client
      @mcp_client = McpConfigLoader.load_and_create_client(@config[:mcp_config])
      unless @mcp_client
        log("No MCP servers configured or failed to load")
        return
      end

      log("MCP client initialized")

      # Create tool executor
      @tool_executor = ToolExecutor.new(mcp_client: @mcp_client, logger: @json_logger)

      # Discover and prepare tools
      begin
        @mcp_tools = @mcp_client.list_tools
        log("Discovered #{@mcp_tools.length} MCP tools from external servers")

        # Register tools with LLM (for internal use only)
        register_tools_with_llm
      rescue StandardError => e
        error("Failed to discover MCP tools: #{e.message}")
        @mcp_tools = []
      end
    end

    def register_tools_with_llm
      return if @mcp_tools.empty? || !@tool_executor

      # Create RubyLLM-compatible tools
      llm_tools = @mcp_tools.map { |tool_info| @tool_executor.create_llm_tool(tool_info) }

      # Register with the chat instance
      @chat.with_tools(*llm_tools)
      log("Registered #{llm_tools.length} MCP tools with LLM for internal use")
    end

    def build_context
      Context.new(
        chat: @chat,
        session_manager: @session_manager,
        logger: @json_logger,
        provider: @config[:provider],
        model: @config[:model],
        temperature: @config[:temperature],
        name: @config[:name],
        calling_instance: @config[:calling_instance],
        calling_instance_id: @config[:calling_instance_id],
        instance_id: @config[:instance_id],
        reasoning_effort: @config[:reasoning_effort],
      )
    end

    def log_startup_info
      log("=" * 50)
      log("LLM-MCP Server v#{VERSION}")
      log("Provider: #{@config[:provider]}")
      log("Model: #{@config[:model]}")
      log("Session: #{@session_manager.session_id}")
      log("Instance: #{@config[:name]}") if @config[:name]
      log("Instance ID: #{@config[:instance_id]}") if @config[:instance_id]
      log("Calling Instance: #{@config[:calling_instance]}") if @config[:calling_instance]
      log("Calling Instance ID: #{@config[:calling_instance_id]}") if @config[:calling_instance_id]
      log("Reasoning Effort: #{@config[:reasoning_effort]}") if @config[:reasoning_effort]
      log("Verbose: #{@verbose}")
      log("=" * 50)
    end

    def log(message)
      warn("[llm-mcp] #{message}") if @verbose
    end

    def error(message)
      warn("[llm-mcp] ERROR: #{message}")
    end
  end
end
