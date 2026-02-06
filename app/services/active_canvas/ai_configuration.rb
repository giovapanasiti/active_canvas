module ActiveCanvas
  class AiConfiguration
    class << self
      def configure_ruby_llm!
        RubyLLM.configure do |config|
          config.openai_api_key = Setting.ai_openai_api_key
          config.anthropic_api_key = Setting.ai_anthropic_api_key
          config.openrouter_api_key = Setting.ai_openrouter_api_key
          config.request_timeout = 120
        end
      end

      def configured?
        Setting.ai_openai_api_key.present? ||
          Setting.ai_anthropic_api_key.present? ||
          Setting.ai_openrouter_api_key.present?
      end

      def text_enabled?
        configured? && Setting.ai_text_enabled?
      end

      def image_enabled?
        configured? && Setting.ai_image_enabled?
      end

      def screenshot_enabled?
        configured? && Setting.ai_screenshot_enabled?
      end

      def configured_providers
        providers = []
        providers << "openai" if Setting.ai_openai_api_key.present?
        providers << "anthropic" if Setting.ai_anthropic_api_key.present?
        providers << "openrouter" if Setting.ai_openrouter_api_key.present?
        providers
      end
    end
  end
end
