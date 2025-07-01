# frozen_string_literal: true

# Combined RubyLLM monkey patches

# Module to control role preservation
module LlmMcp
  module RolePreservation
    class << self
      attr_accessor :preserve_roles
    end
    self.preserve_roles = false
  end
end

# Main Chat patches
module RubyLLMChatPatch
  def initialize(model: nil, provider: nil, assume_model_exists: false, context: nil)
    super
    @custom_options = {} # Initialize custom options hash after super
  end

  # Add a new method to set custom options (generic)
  def with_options(**options)
    dup.tap { |chat| chat.instance_variable_set(:@custom_options, @custom_options.merge(options)) }
  end

  # Convenience method for max_tokens
  def with_max_tokens(max_tokens)
    with_options(max_tokens: max_tokens)
  end

  # Override complete to pass options through the provider
  def complete(&)
    # Store options on the provider temporarily
    if @provider.respond_to?(:custom_options=)
      old_options = @provider.custom_options
      @provider.custom_options = @custom_options
    end

    super
  ensure
    # Restore previous options
    @provider.custom_options = old_options if @provider.respond_to?(:custom_options=)
  end
end

# Patch Provider module to support custom options
module RubyLLMProviderPatch
  class << self
    def extended(base)
      base.singleton_class.class_eval do
        attr_accessor(:custom_options)
      end
    end
  end

  # Override render_payload to merge custom options
  def render_payload(messages, tools:, temperature:, model:, stream:)
    payload = super
    payload.merge!(custom_options || {})
    payload
  end
end

# Role preservation patches for providers
module RubyLLM
  module Providers
    module OpenAI
      module Chat
        # Store the original method
        alias_method :original_format_role, :format_role

        # Override format_role to optionally preserve all roles
        def format_role(role)
          if LlmMcp::RolePreservation.preserve_roles
            role.to_s
          else
            original_format_role(role)
          end
        end
      end
    end

    module Gemini
      module Chat
        alias_method :original_format_role, :format_role if method_defined?(:format_role)

        def format_role(role)
          if LlmMcp::RolePreservation.preserve_roles
            role.to_s
          else
            original_format_role(role)
          end
        rescue NoMethodError
          case role
          when :assistant then "model"
          when :system, :tool then "user"
          else role.to_s
          end
        end
      end
    end

    module Anthropic
      module Chat
        alias_method :original_convert_role, :convert_role if method_defined?(:convert_role)

        def convert_role(role)
          if LlmMcp::RolePreservation.preserve_roles
            role.to_s
          else
            original_convert_role(role)
          end
        rescue NoMethodError
          case role
          when :tool, :user then "user"
          else "assistant"
          end
        end
      end
    end
  end
end

# Apply the Chat patches
RubyLLM::Chat.prepend(RubyLLMChatPatch)

# Apply the provider patch to all existing providers
RubyLLM::Provider.providers.each do |_name, provider_module|
  # First extend the patch to add methods and attributes
  provider_module.extend(RubyLLMProviderPatch) unless provider_module.singleton_class.include?(RubyLLMProviderPatch)

  # Then patch the Chat module's render_payload method
  next unless provider_module.const_defined?(:Chat)

  chat_module = provider_module.const_get(:Chat)
  # Only patch if render_payload method exists
  next unless chat_module.method_defined?(:render_payload)

  chat_module.module_eval do
    alias_method :original_render_payload, :render_payload unless method_defined?(:original_render_payload)

    define_method :render_payload do |messages, tools:, temperature:, model:, stream:|
      payload = original_render_payload(messages, tools: tools, temperature: temperature, model: model, stream: stream)
      # Get custom options from the provider module
      payload.merge!(provider_module.custom_options) if provider_module.respond_to?(:custom_options) && provider_module.custom_options
      payload
    end
  end
end

# Ensure future providers also get the patch
module RubyLLM
  module Provider
    class << self
      alias_method :original_register, :register unless method_defined?(:original_register)

      def register(name, provider_module)
        # Extend the provider module
        provider_module.extend(RubyLLMProviderPatch) unless provider_module.singleton_class.include?(RubyLLMProviderPatch)

        # Patch the Chat module if it exists
        if provider_module.const_defined?(:Chat)
          chat_module = provider_module.const_get(:Chat)
          # Only patch if render_payload method exists
          if chat_module.method_defined?(:render_payload)
            chat_module.module_eval do
              alias_method(:original_render_payload, :render_payload) unless method_defined?(:original_render_payload)

              define_method(:render_payload) do |messages, tools:, temperature:, model:, stream:|
                payload = original_render_payload(messages, tools: tools, temperature: temperature, model: model, stream: stream)
                payload.merge!(provider_module.custom_options) if provider_module.respond_to?(:custom_options) && provider_module.custom_options
                payload
              end
            end
          end
        end

        original_register(name, provider_module)
      end
    end
  end
end
