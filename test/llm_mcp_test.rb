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
    assert_includes(RubyLLM::Chat.instance_methods, :with_max_tokens)
    assert(LlmMcp.const_defined?(:RolePreservation))
  end
end
