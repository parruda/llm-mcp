# frozen_string_literal: true

require "ruby_llm"

module LlmMcp
  class ProviderFactory
    class << self
      def create(provider:, model:, base_url: nil, append_system_prompt: nil, skip_model_validation: false)
        configure_provider(provider, base_url)

        chat_args = {
          model: model,
          provider: provider_symbol(provider)
        }
        chat_args[:assume_model_exists] = true if skip_model_validation

        chat = RubyLLM.chat(**chat_args)

        chat.with_instructions(append_system_prompt) if append_system_prompt

        chat
      end

      private

      def provider_symbol(provider)
        case provider.downcase
        when "openai"
          :openai
        when "google", "gemini"
          :gemini
        else
          raise ArgumentError, "Unsupported provider: #{provider}. Supported: openai, google"
        end
      end

      def configure_provider(provider, base_url)
        case provider.downcase
        when "openai"
          configure_openai(base_url)
        when "google", "gemini"
          configure_google
        end
      end

      def configure_openai(base_url)
        RubyLLM.configure do |config|
          config.openai_api_key = ENV["OPENAI_API_KEY"] || raise("OPENAI_API_KEY not set")
          config.openai_api_base = base_url if base_url
        end
      end

      def configure_google
        RubyLLM.configure do |config|
          config.gemini_api_key = ENV["GEMINI_API_KEY"] || ENV["GOOGLE_API_KEY"] || raise("GEMINI_API_KEY or GOOGLE_API_KEY not set")
        end
      end
    end
  end
end
