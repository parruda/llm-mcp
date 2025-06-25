# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "llm_mcp"

require "minitest/autorun"
begin
  require "webmock/minitest"
rescue LoadError
  # WebMock is optional for some tests
end
require "tmpdir"
