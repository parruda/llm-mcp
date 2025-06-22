# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.setup

module LlmMcp
  class Error < StandardError; end
  # Your code goes here...
end

loader.eager_load
