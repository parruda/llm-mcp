# frozen_string_literal: true

require "test_helper"

class LlmMcpTest < Minitest::Test
  def test_defines_error_class
    assert(LlmMcp.const_defined?(:Error))
    assert_equal(StandardError, LlmMcp::Error.superclass)
  end

  def test_error_class_can_be_raised
    error_message = "Something went wrong"

    assert_raises(LlmMcp::Error) do
      raise LlmMcp::Error, error_message
    end

    begin
      raise LlmMcp::Error, error_message
    rescue LlmMcp::Error => e
      assert_equal(error_message, e.message)
    end
  end

  def test_defines_context_struct
    assert(LlmMcp.const_defined?(:Context))
    assert_kind_of(Class, LlmMcp::Context)
  end

  def test_context_struct_has_required_attributes
    context = LlmMcp::Context.new

    # Test all expected attributes exist
    assert_respond_to(context, :chat)
    assert_respond_to(context, :logger)
    assert_respond_to(context, :model)
    assert_respond_to(context, :provider)
    assert_respond_to(context, :session_manager)

    # Test setters exist
    assert_respond_to(context, :chat=)
    assert_respond_to(context, :logger=)
    assert_respond_to(context, :model=)
    assert_respond_to(context, :provider=)
    assert_respond_to(context, :session_manager=)
  end

  def test_context_supports_keyword_initialization
    chat = Object.new
    logger = Object.new
    model = "gpt-4"
    provider = "openai"
    session_manager = Object.new

    context = LlmMcp::Context.new(
      chat: chat,
      logger: logger,
      model: model,
      provider: provider,
      session_manager: session_manager,
    )

    assert_equal(chat, context.chat)
    assert_equal(logger, context.logger)
    assert_equal(model, context.model)
    assert_equal(provider, context.provider)
    assert_equal(session_manager, context.session_manager)
  end

  def test_context_allows_partial_initialization
    logger = Object.new

    context = LlmMcp::Context.new(logger: logger)

    assert_nil(context.chat)
    assert_equal(logger, context.logger)
    assert_nil(context.model)
    assert_nil(context.provider)
    assert_nil(context.session_manager)
  end

  def test_all_core_classes_are_loaded
    # Test that all main classes are autoloaded
    core_classes = [
      :CLI,
      :JsonLogger,
      :McpConfigLoader,
      :McpToolAdapter,
      :ProviderFactory,
      :Server,
      :SessionManager,
      :ToolExecutor,
    ]

    core_classes.each do |class_name|
      assert(LlmMcp.const_defined?(class_name), "LlmMcp::#{class_name} should be defined")
      assert_kind_of(Class, LlmMcp.const_get(class_name))
    end
  end

  def test_tool_classes_are_loaded
    tool_classes = [
      :ResetSessionTool,
      :TaskTool,
    ]

    tool_classes.each do |class_name|
      assert(LlmMcp::Tools.const_defined?(class_name), "LlmMcp::Tools::#{class_name} should be defined")
      assert_kind_of(Class, LlmMcp::Tools.const_get(class_name))
    end
  end

  def test_required_gems_are_available
    # Test that all required gems are loaded
    required_modules = [
      Thor,
      FastMcp,
      RubyLLM,
      JSON,
      FileUtils,
      Concurrent,
      MCPClient,
    ]

    required_modules.each do |mod|
      assert(mod, "#{mod} should be loaded")
    end
  end

  def test_monkey_patches_are_applied
    # Test that monkey patches from monkey_patches.rb are loaded
    assert(RubyLLM::Chat.instance_methods.include?(:with_max_tokens))
    assert(RubyLLM::Chat.instance_methods.include?(:original_complete))
    assert(LlmMcp.const_defined?(:RolePreservation))
  end
end
