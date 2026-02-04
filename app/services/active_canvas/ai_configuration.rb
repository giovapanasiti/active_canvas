module ActiveCanvas
  class AiConfiguration
    class << self
      def configure_ruby_llm!
        raise_if_ruby_llm_not_available!

        RubyLLM.configure do |config|
          config.openai_api_key = Setting.ai_openai_api_key
          config.anthropic_api_key = Setting.ai_anthropic_api_key
          config.openrouter_api_key = Setting.ai_openrouter_api_key
          config.request_timeout = 120
        end
      end

      def ruby_llm_available?
        defined?(RubyLLM) && RubyLLM.respond_to?(:configure)
      end

      def configured?
        ruby_llm_available? && (
          Setting.ai_openai_api_key.present? ||
          Setting.ai_anthropic_api_key.present? ||
          Setting.ai_openrouter_api_key.present?
        )
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
        return [] unless ruby_llm_available?

        providers = []
        providers << "openai" if Setting.ai_openai_api_key.present?
        providers << "anthropic" if Setting.ai_anthropic_api_key.present?
        providers << "openrouter" if Setting.ai_openrouter_api_key.present?
        providers
      end

      private

      def raise_if_ruby_llm_not_available!
        return if ruby_llm_available?

        raise LoadError, "RubyLLM gem is not available. Add 'ruby_llm' to your Gemfile."
      end
    end
  end
end
