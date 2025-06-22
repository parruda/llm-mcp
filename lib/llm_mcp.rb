# frozen_string_literal: true

require "zeitwerk"
require "thor"
require "fast_mcp"
require "ruby_llm"
require "json"
require "fileutils"
require "concurrent"

# Load monkey patches after ruby_llm is loaded
require_relative "llm_mcp/monkey_patches"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "cli" => "CLI",
  "mcp" => "MCP"
)
loader.ignore("#{__dir__}/llm_mcp/monkey_patches.rb")
loader.setup

module LlmMcp
  class Error < StandardError; end
end

loader.eager_load
