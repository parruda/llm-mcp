# frozen_string_literal: true

module LlmMcp
  class CLI < Thor
    class << self
      def exit_on_failure?
        true
      end
    end

    desc "mcp-serve", "Start an MCP server that exposes LLMs"
    option :provider, required: true, desc: "LLM provider (openai, google)"
    option :model, required: true, desc: "Model to use"
    option :base_url, desc: "Custom base URL for OpenAI-compatible APIs"
    option :append_system_prompt, desc: "Additional system prompt to append"
    option :verbose, type: :boolean, default: false, desc: "Enable verbose logging"
    option :json_log_path, desc: "Path to JSON log file"
    option :mcp_config, desc: "Path to MCP configuration JSON file"
    option :session_id, desc: "Session identifier (defaults to timestamp)"
    option :session_path, desc: "Custom session storage path"
    option :skip_model_validation, type: :boolean, default: false, desc: "Skip model name validation (for custom models)"
    option :temperature, type: :numeric, desc: "Temperature for response generation (0.0-2.0)"
    option :reasoning_effort, type: :string, desc: "Reasoning effort for response generation (low, medium, high)"
    option :name, desc: "Name for this instance"
    option :calling_instance, desc: "Name of the calling instance"
    option :calling_instance_id, desc: "ID of the calling instance"
    option :instance_id, desc: "ID for this instance"
    def mcp_serve
      server = Server.new(options)
      server.start
    rescue StandardError => e
      error("Error: #{e.message}")
      error(e.backtrace.join("\n")) if options[:verbose]
      exit(1)
    end

    desc "version", "Show version"
    def version
      puts "llm-mcp #{VERSION}"
    end

    private

    def error(message)
      warn(message)
    end
  end
end
