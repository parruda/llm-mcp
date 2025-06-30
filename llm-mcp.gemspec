# frozen_string_literal: true

require_relative "lib/llm_mcp/version"

Gem::Specification.new do |spec|
  spec.name = "llm-mcp"
  spec.version = LlmMcp::VERSION
  spec.authors = ["Paulo Arruda"]
  spec.email = ["parrudaj@gmail.com"]

  spec.summary = "Expose LLMs from multiple providers via MCP protocol"
  spec.description = "A Ruby gem that creates MCP servers to expose LLMs (OpenAI, Google, etc.) " \
    "with standardized tools for chat and session management"
  spec.homepage = "https://github.com/parruda/llm-mcp"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/parruda/llm-mcp"
  spec.metadata["changelog_uri"] = "https://github.com/parruda/llm-mcp/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(["git", "ls-files", "-z"], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?("bin/", "test/", "spec/", "features/", ".git", "appveyor", "Gemfile")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency("fast-mcp-annotations", "~> 1.5")
  spec.add_dependency("json", "~> 2.6")
  spec.add_dependency("logger", "~> 1.6")
  spec.add_dependency("ruby_llm", "~> 1.3")
  spec.add_dependency("ruby-mcp-client", "~> 0.7")
  spec.add_dependency("thor", "~> 1.3")
  spec.add_dependency("zeitwerk", "~> 2.6")
end
