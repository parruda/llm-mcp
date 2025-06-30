# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/test/"
end

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "llm_mcp"

require "minitest/autorun"
require "webmock/minitest"
require "tmpdir"
require "stringio"
require "timecop"
