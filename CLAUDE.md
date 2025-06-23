# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

llm-mcp is a Ruby gem that exposes Large Language Models (LLMs) via the Model Context Protocol (MCP). It creates MCP servers that provide standardized access to OpenAI, Google Gemini, and OpenAI-compatible APIs, with session management and external MCP tool integration capabilities.

## Development Commands

```bash
# Install dependencies
bundle install

# Run all tests (unit + integration)
bundle exec rake test

# Run linter with auto-fix
bundle exec rubocop -A

# Run tests and linter (default task)
rake

# Install gem locally for testing
bundle exec rake install

# Run specific test file
bundle exec ruby -Ilib:test test/llm_mcp/cli_test.rb

# Run tests matching a pattern
bundle exec ruby -Ilib:test test/llm_mcp/cli_test.rb -n /test_name_pattern/
```

## Architecture Overview

### Core Components

1. **CLI Interface** (`lib/llm_mcp/cli.rb`): Thor-based CLI handling command parsing and server startup via `mcp-serve` command.

2. **MCP Server** (`lib/llm_mcp/server.rb`): Sets up FastMCP server with tools for LLM interaction. Handles provider initialization and MCP tool registration.

3. **Provider System**: 
   - `ProviderFactory` creates LLM provider instances based on configuration
   - Supports OpenAI, Google Gemini, and OpenAI-compatible endpoints
   - Providers are initialized with API keys from environment variables

4. **Session Management** (`lib/llm_mcp/session_manager.rb`):
   - File-based persistence in `~/.llm-mcp/sessions/`
   - Maintains conversation history across server restarts
   - Thread-safe with mutex protection

5. **MCP Integration**:
   - **As Server**: Exposes `task` and `reset_session` tools for LLM interaction
   - **As Client**: Connects to external MCP servers via `McpConfigLoader` and `McpToolAdapter`
   - Tools are dynamically registered based on configuration

6. **Logging** (`lib/llm_mcp/json_logger.rb`): Thread-safe JSON logging with file locking for concurrent access safety.

### Key Design Patterns

- **Factory Pattern**: `ProviderFactory` for creating different LLM providers
- **Adapter Pattern**: `McpToolAdapter` converts external MCP tools for LLM usage
- **Command Pattern**: Tool classes (`TaskTool`, `ResetSessionTool`) encapsulate operations
- **Singleton-like Sessions**: One session manager instance per server

### External Dependencies

The gem integrates with:
- `ruby_llm`: Core LLM abstraction layer (with monkey patches in `lib/llm_mcp/monkey_patches.rb`)
- `fast-mcp-annotations`: Simplified MCP server creation
- `ruby-mcp-client`: MCP client functionality for connecting to external servers
- `thor`: Command-line interface framework
- `zeitwerk`: Code loading and autoloading

## Testing Approach

Tests are organized into:
- **Unit tests** (`test/llm_mcp/*`): Test individual components in isolation
- **Integration tests** (`test/integration/*`): Test server behavior and tool interactions
- Mock external services using WebMock
- Use `test_helper.rb` for common test setup and utilities

## MCP Configuration

External MCP servers are configured via JSON:
```json
{
  "servers": {
    "server-name": {
      "command": "command-to-start-server",
      "args": ["arg1", "arg2"],
      "env": { "KEY": "value" }
    }
  }
}
```

The server dynamically discovers and registers tools from configured MCP servers.

## Development Team

This project uses Claude Swarm with specialized agents defined in `team.yml`:
- **architect**: Overall system design and coordination
- **planner**: Implementation roadmaps and task breakdown
- **adversarial_critic**: Code quality and security review
- **lead_developer**: Feature implementation
- **github_expert**: GitHub operations and releases
- **ruby_llm_expert**: ruby_llm library specialist
- **ruby_mcp_client_expert**: MCP client integration specialist
- **fast_mcp_expert**: MCP server development specialist

## Git Configuration

When committing code, use: `Paulo Arruda <parrudaj@gmail.com>` as the author.