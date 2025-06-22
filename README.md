# llm-mcp

A Ruby gem that exposes Large Language Models (LLMs) via the Model Context Protocol (MCP), enabling seamless integration of AI capabilities into your development workflow.

## Overview

llm-mcp creates an MCP server that provides standardized access to various LLM providers (OpenAI, Google Gemini, and OpenAI-compatible APIs) while supporting advanced features like session management, conversation persistence, and integration with external MCP tools.

### Key Features

- 🤖 **Multi-Provider Support**: Works with OpenAI, Google Gemini, and any OpenAI-compatible API
- 💬 **Session Management**: Persist conversations across server restarts
- 🔧 **MCP Tool Integration**: Connect to external MCP servers and use their tools within LLM conversations
- 📝 **Comprehensive Logging**: JSON-formatted logs for debugging and analysis
- 🔌 **Extensible Architecture**: Easy to add new providers and customize behavior
- 🚀 **Built on FastMCP**: Leverages the fast and efficient MCP server framework

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'llm-mcp'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install llm-mcp
```

## Configuration

### Environment Variables

Set up your API keys based on the provider you want to use:

```bash
# For OpenAI
export OPENAI_API_KEY="your-openai-api-key"

# For Google Gemini
export GEMINI_API_KEY="your-gemini-api-key"
# or
export GOOGLE_API_KEY="your-google-api-key"
```

## Usage

### Basic Usage

Start an MCP server that exposes an LLM:

```bash
# Using OpenAI
llm-mcp mcp-serve --provider openai --model gpt-4

# Using Google Gemini
llm-mcp mcp-serve --provider google --model gemini-1.5-flash

# Using a custom OpenAI-compatible API
llm-mcp mcp-serve --provider openai --model llama-3.1-8b --base-url https://api.groq.com/openai/v1
```

### Advanced Options

```bash
llm-mcp mcp-serve \
  --provider openai \
  --model gpt-4 \
  --verbose \                           # Enable verbose logging
  --json-log-path logs/llm.json \      # Log to JSON file
  --session-id my-project \             # Resume a specific session
  --session-path ~/my-sessions \        # Custom session storage location
  --append-system-prompt "You are a Ruby expert" \  # Add to system prompt
  --skip-model-validation              # Skip model name validation
```

### Connecting to External MCP Servers

llm-mcp can connect to other MCP servers, allowing the LLM to use their tools:

1. Create an MCP configuration file (e.g., `~/.mcp/config.json`):

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-filesystem", "/tmp"]
    },
    "github": {
      "command": "mcp-github",
      "env": {
        "GITHUB_TOKEN": "your-github-token"
      }
    },
    "http-api": {
      "url": "https://api.example.com/mcp/sse",
      "transport": "sse",
      "headers": {
        "Authorization": "Bearer your-token"
      }
    }
  }
}
```

2. Start llm-mcp with the configuration:

```bash
llm-mcp mcp-serve \
  --provider openai \
  --model gpt-4 \
  --mcp-config ~/.mcp/config.json
```

Now the LLM can use tools from the connected MCP servers in its responses!

## MCP Tools Exposed

### `task`

Send a request to the LLM and get a response.

**Parameters:**
- `prompt` (required): The message or question for the LLM
- `temperature` (optional): Control randomness (0.0-2.0, default: 0.7)
- `max_tokens` (optional): Maximum response length

**Example Request:**
```json
{
  "method": "tools/call",
  "params": {
    "name": "task",
    "arguments": {
      "prompt": "Explain the concept of dependency injection",
      "temperature": 0.7,
      "max_tokens": 500
    }
  }
}
```

### `reset_session`

Clear the conversation history and start fresh.

**Example Request:**
```json
{
  "method": "tools/call",
  "params": {
    "name": "reset_session",
    "arguments": {}
  }
}
```

## Session Management

Sessions automatically persist conversations to disk, allowing you to:

- Resume previous conversations
- Maintain context across server restarts
- Track token usage over time

Sessions are stored in `~/.llm-mcp/sessions/` by default, with each session saved as a JSON file.

### Session Files

Session files contain:
- Message history (user, assistant, and system messages)
- Timestamps for each interaction
- Token usage statistics
- Session metadata

## Logging

Enable JSON logging for comprehensive debugging:

```bash
llm-mcp mcp-serve \
  --provider openai \
  --model gpt-4 \
  --json-log-path logs/llm.json \
  --verbose
```

Logs include:
- All requests and responses
- Tool calls and their results
- Session operations
- Error messages and stack traces

## Integration Examples

### Using with Claude Desktop

Add to your Claude Desktop configuration (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "llm-mcp": {
      "command": "llm-mcp",
      "args": ["mcp-serve", "--provider", "openai", "--model", "gpt-4"],
      "env": {
        "OPENAI_API_KEY": "your-api-key"
      }
    }
  }
}
```

### Using with mcp-client

```ruby
require 'mcp-client'

client = MCP::Client.new
client.connect_stdio('llm-mcp', 'mcp-serve', '--provider', 'openai', '--model', 'gpt-4')

# Use the task tool
response = client.call_tool('task', {
  prompt: "Write a haiku about Ruby programming",
  temperature: 0.9
})

puts response.content
```

### Combining Multiple MCP Servers

Create a powerful AI assistant by combining llm-mcp with other MCP servers:

```json
{
  "mcpServers": {
    "llm": {
      "command": "llm-mcp",
      "args": ["mcp-serve", "--provider", "openai", "--model", "gpt-4", "--mcp-config", "mcp-tools.json"]
    },
    "filesystem": {
      "command": "mcp-filesystem",
      "args": ["/project"]
    },
    "git": {
      "command": "mcp-git"
    }
  }
}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests.

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rake test

# Run linter
bundle exec rubocop -A

# Install gem locally
bundle exec rake install
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/parruda/llm-mcp.

## License

The gem is available as open source under the terms of the MIT License.