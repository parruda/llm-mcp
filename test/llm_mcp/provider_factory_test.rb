# frozen_string_literal: true

require "test_helper"

class ProviderFactoryTest < Minitest::Test
  def setup
    # Mock environment variables
    ENV["OPENAI_API_KEY"] = "test-openai-key"
    ENV["GEMINI_API_KEY"] = "test-gemini-key"
  end

  def teardown
    ENV.delete("OPENAI_API_KEY")
    ENV.delete("GEMINI_API_KEY")
  end

  def test_creates_openai_provider
    # Mock RubyLLM configuration and chat creation
    mock_chat = Minitest::Mock.new

    RubyLLM.stub :configure, lambda { |&block|
      config = Minitest::Mock.new
      config.expect :openai_api_key=, nil, ["test-openai-key"]
      block&.call(config)
    } do
      RubyLLM.stub :chat, mock_chat do
        result = LlmMcp::ProviderFactory.create(
          provider: "openai",
          model: "gpt-4"
        )

        assert result # Just ensure we got something back
      end
    end
  end

  def test_creates_google_provider
    mock_chat = Minitest::Mock.new

    RubyLLM.stub :configure, lambda { |&block|
      config = Minitest::Mock.new
      config.expect :gemini_api_key=, nil, ["test-gemini-key"]
      block&.call(config)
    } do
      RubyLLM.stub :chat, mock_chat do
        result = LlmMcp::ProviderFactory.create(
          provider: "google",
          model: "gemini-pro"
        )

        assert result # Just ensure we got something back
      end
    end
  end

  def test_supports_custom_base_url
    custom_url = "https://custom.openai.com/v1"

    RubyLLM.stub :configure, lambda { |&block|
      config = Minitest::Mock.new
      config.expect :openai_api_key=, nil, ["test-openai-key"]
      config.expect :openai_api_base=, nil, [custom_url]
      block&.call(config)
    } do
      RubyLLM.stub :chat, Minitest::Mock.new do
        LlmMcp::ProviderFactory.create(
          provider: "openai",
          model: "gpt-4",
          base_url: custom_url
        )
      end
    end
  end

  def test_appends_system_prompt
    mock_chat = Minitest::Mock.new
    mock_chat.expect :with_instructions, mock_chat, ["You are helpful"]

    RubyLLM.stub :configure, lambda { |&block|
      config = Minitest::Mock.new
      config.expect :openai_api_key=, nil, ["test-openai-key"]
      block&.call(config)
    } do
      RubyLLM.stub :chat, mock_chat do
        LlmMcp::ProviderFactory.create(
          provider: "openai",
          model: "gpt-4",
          append_system_prompt: "You are helpful"
        )

        mock_chat.verify
      end
    end
  end

  def test_raises_for_unsupported_provider
    assert_raises(ArgumentError) do
      LlmMcp::ProviderFactory.create(
        provider: "unsupported",
        model: "some-model"
      )
    end
  end

  def test_raises_when_api_key_missing
    ENV.delete("OPENAI_API_KEY")

    assert_raises(RuntimeError) do
      LlmMcp::ProviderFactory.create(
        provider: "openai",
        model: "gpt-4"
      )
    end
  end

  def test_accepts_gemini_as_google_alias
    mock_chat = Minitest::Mock.new

    RubyLLM.stub :configure, lambda { |&block|
      config = Minitest::Mock.new
      config.expect :gemini_api_key=, nil, ["test-gemini-key"]
      block&.call(config)
    } do
      RubyLLM.stub :chat, mock_chat do
        result = LlmMcp::ProviderFactory.create(
          provider: "gemini",
          model: "gemini-pro"
        )

        assert result # Just ensure we got something back
      end
    end
  end
end
