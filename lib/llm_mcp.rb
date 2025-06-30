# frozen_string_literal: true

require "zeitwerk"
require "forwardable"
require "thor"
require "fast_mcp"
require "ruby_llm"
require "json"
require "fileutils"
require "concurrent"
require "mcp_client"
require "time"

# Load monkey patches after ruby_llm is loaded
require_relative "llm_mcp/monkey_patches"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "cli" => "CLI",
  "mcp" => "MCP",
)
loader.ignore("#{__dir__}/llm_mcp/monkey_patches.rb")
loader.setup

module LlmMcp
  class Error < StandardError; end

  Context = Struct.new(
    :chat,
    :logger,
    :model,
    :provider,
    :session_manager,
    :temperature,
    :name,
    :calling_instance,
    :calling_instance_id,
    :instance_id,
    :reasoning_effort,
    keyword_init: true,
  )
end

loader.eager_load
