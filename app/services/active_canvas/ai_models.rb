module ActiveCanvas
  class AiModels
    # Fallback models when database is empty
    DEFAULT_TEXT_MODELS = [
      { id: "gpt-4o", name: "GPT-4o", provider: "openai" },
      { id: "gpt-4o-mini", name: "GPT-4o Mini", provider: "openai" },
      { id: "claude-sonnet-4-20250514", name: "Claude Sonnet 4", provider: "anthropic" },
      { id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", provider: "anthropic" }
    ].freeze

    DEFAULT_IMAGE_MODELS = [
      { id: "dall-e-3", name: "DALL-E 3", provider: "openai" },
      { id: "gpt-image-1", name: "GPT Image 1", provider: "openai" }
    ].freeze

    DEFAULT_VISION_MODELS = [
      { id: "gpt-4o", name: "GPT-4o", provider: "openai" },
      { id: "gpt-4o-mini", name: "GPT-4o Mini", provider: "openai" },
      { id: "claude-sonnet-4-20250514", name: "Claude Sonnet 4", provider: "anthropic" },
      { id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", provider: "anthropic" }
    ].freeze

    class << self
      def refresh!
        AiModel.refresh_from_ruby_llm!
      end

      def text_models
        models = fetch_text_models_from_db
        return models if models.any?

        filter_by_configured_providers(DEFAULT_TEXT_MODELS)
      end

      def image_models
        models = fetch_image_models_from_db
        return models if models.any?

        filter_by_configured_providers(DEFAULT_IMAGE_MODELS)
      end

      def vision_models
        models = fetch_vision_models_from_db
        return models if models.any?

        filter_by_configured_providers(DEFAULT_VISION_MODELS)
      end

      def all_text_models
        models = AiModel.active.chat_models.order(:provider, :name)
        return models.map(&:as_json_for_editor) if models.any?

        DEFAULT_TEXT_MODELS
      end

      def all_image_models
        models = AiModel.active.image_models.order(:provider, :name)
        return models.map(&:as_json_for_editor) if models.any?

        DEFAULT_IMAGE_MODELS
      end

      def all_vision_models
        models = AiModel.active.chat_models.with_vision.order(:provider, :name)
        return models.map(&:as_json_for_editor) if models.any?

        DEFAULT_VISION_MODELS
      end

      def find_by_id(model_id)
        AiModel.find_by(model_id: model_id)
      end

      def models_synced?
        AiModel.exists?
      end

      def last_synced_at
        AiModel.maximum(:updated_at)
      end

      private

      def fetch_text_models_from_db
        providers = configured_providers
        return [] if providers.empty?

        models = AiModel.text_models_for_providers(providers)
        models.map(&:as_json_for_editor)
      end

      def fetch_image_models_from_db
        providers = configured_providers
        return [] if providers.empty?

        models = AiModel.image_models_for_providers(providers)
        models.map(&:as_json_for_editor)
      end

      def fetch_vision_models_from_db
        providers = configured_providers
        return [] if providers.empty?

        models = AiModel.vision_models_for_providers(providers)
        models.map(&:as_json_for_editor)
      end

      def configured_providers
        AiConfiguration.configured_providers
      end

      def filter_by_configured_providers(models)
        providers = configured_providers
        return [] if providers.empty?

        models.select { |m| providers.include?(m[:provider]) }
      end
    end
  end
end
