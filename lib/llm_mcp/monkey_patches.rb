# frozen_string_literal: true

# Monkey patches for ruby_llm to customize behavior

# Add with_max_tokens method to RubyLLM::Chat
module RubyLLM
  class Chat
    def with_max_tokens(max_tokens)
      dup.tap { |chat| chat.instance_variable_set(:@max_tokens, max_tokens) }
    end

    # Override complete to use max_tokens if set
    alias original_complete complete

    def complete
      options = {}
      options[:max_tokens] = @max_tokens if instance_variable_defined?(:@max_tokens) && @max_tokens

      if options.empty?
        original_complete
      else
        original_complete(**options)
      end
    end
  end
end

module LlmMcp
  # Module to control whether role preservation is active
  module RolePreservation
    class << self
      attr_accessor :preserve_roles
    end

    self.preserve_roles = false
  end
end

module RubyLLM
  module Providers
    module OpenAI
      module Chat
        # Store the original method
        alias original_format_role format_role

        # Override format_role to optionally preserve all roles
        def format_role(role)
          if LlmMcp::RolePreservation.preserve_roles
            # When preserve_roles is active, keep all roles as-is
            role.to_s
          else
            # Use original behavior
            original_format_role(role)
          end
        end
      end
    end

    # Also patch Gemini provider if needed
    module Gemini
      module Chat
        alias original_format_role format_role if method_defined?(:format_role)

        def format_role(role)
          if LlmMcp::RolePreservation.preserve_roles
            # When preserve_roles is active, keep all roles as-is
            role.to_s
          else
            # Use original behavior
            original_format_role(role)
          end
        rescue NoMethodError
          # If original method doesn't exist, fall back to default behavior
          case role
          when :assistant then "model"
          when :system, :tool then "user"
          else role.to_s
          end
        end
      end
    end

    # Patch Anthropic provider if needed
    module Anthropic
      module Chat
        alias original_convert_role convert_role if method_defined?(:convert_role)

        def convert_role(role)
          if LlmMcp::RolePreservation.preserve_roles
            # When preserve_roles is active, keep all roles as-is
            role.to_s
          else
            # Use original behavior
            original_convert_role(role)
          end
        rescue NoMethodError
          # If original method doesn't exist, fall back to default behavior
          case role
          when :tool, :user then "user"
          else "assistant"
          end
        end
      end
    end
  end
end
