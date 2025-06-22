# LLM-MCP Implementation Plan

## Overview
Build a Ruby gem that exposes LLMs from multiple providers via MCP protocol with two tools:
- Task: Send a request to the LLM, return the response
- Reset Session: Clear the context of the conversation

## Architecture

### Core Components

1. **CLI (Thor-based)**
   - Command: `llm-mcp mcp-serve`
   - Flags:
     - `--provider` (openai, google)
     - `--model` (model name)
     - `--base-url` (custom base URL for OpenAI-compatible APIs)
     - `--append-system-prompt` (additional system prompt)
     - `--verbose` (verbose logging)
     - `--json-log-path` (path to JSON log file)
     - `--mcp-config` (path to MCP config JSON)
     - `--session-id` (session identifier)
     - `--session-path` (custom session storage path)

2. **MCP Server (using fast-mcp-annotations)**
   - TaskTool: Handles LLM chat requests
   - ResetSessionTool: Clears conversation context
   - Server configured with name and version

3. **Session Manager**
   - File-based persistence to ~/.llm-mcp/sessions
   - Session ID format: YYYYMMDD_HHMMSS or custom
   - Stores conversation history
   - Resume capability

4. **LLM Provider Integration (ruby_llm)**
   - Support OpenAI, Google Gemini
   - Custom base URL support for OpenAI-compatible APIs
   - Conversation history management

5. **JSON Logger**
   - File locking for concurrent writes
   - Log format: JSONL (one JSON per line)
   - Captures: requests, responses, tool calls, tool responses

6. **MCP Client Integration (ruby_llm-mcp)**
   - Load MCP server configs from JSON
   - Connect LLM to external MCP tools
   - Handle tool execution

## Implementation Steps

### Phase 1: Foundation
1. Update gemspec with dependencies
2. Set up module structure
3. Create CLI skeleton

### Phase 2: Core MCP Server
1. Implement TaskTool
2. Implement ResetSessionTool
3. Create server initialization

### Phase 3: Session Management
1. Create SessionManager class
2. Implement file-based persistence
3. Add session resume logic

### Phase 4: Provider Integration
1. Create provider factory
2. Implement OpenAI provider
3. Implement Google provider
4. Add custom base URL support

### Phase 5: Logging
1. Create JSONLogger with file locking
2. Implement request/response capture
3. Add tool call logging

### Phase 6: MCP Client Integration
1. Parse MCP config JSON
2. Create MCP clients
3. Register tools with LLM

### Phase 7: Testing & Polish
1. Unit tests for each component
2. Integration tests
3. Rubocop fixes
4. Documentation

## File Structure
```
lib/
├── llm_mcp.rb              # Main module
├── llm_mcp/
│   ├── version.rb
│   ├── cli.rb              # Thor CLI
│   ├── server.rb           # MCP server setup
│   ├── tools/
│   │   ├── task_tool.rb
│   │   └── reset_session_tool.rb
│   ├── session_manager.rb  # Session persistence
│   ├── provider_factory.rb # LLM provider creation
│   ├── json_logger.rb      # Logging with file lock
│   └── mcp_config_loader.rb # Load and create MCP clients
test/
├── test_helper.rb
├── llm_mcp/
│   ├── cli_test.rb
│   ├── tools/
│   │   ├── task_tool_test.rb
│   │   └── reset_session_tool_test.rb
│   ├── session_manager_test.rb
│   ├── provider_factory_test.rb
│   ├── json_logger_test.rb
│   └── mcp_config_loader_test.rb
└── integration/
    └── server_test.rb
```

## Key Design Decisions

1. **Fast-MCP for server**: Provides Ruby-native MCP implementation
2. **File-based sessions**: Simple, portable, no external dependencies
3. **Thor for CLI**: Robust, well-tested CLI framework
4. **JSON file locking**: Prevents corruption with concurrent writes
5. **Provider abstraction**: Easy to add new LLM providers

## Testing Strategy

1. Unit tests for each component
2. Integration tests for full server operation
3. Mock external services (LLM APIs, MCP servers)
4. Test concurrent logging scenarios
5. Test session resume functionality