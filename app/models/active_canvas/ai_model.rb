module ActiveCanvas
  class AiModel < ApplicationRecord
    validates :model_id, presence: true, uniqueness: true
    validates :provider, presence: true

    scope :active, -> { where(active: true) }
    scope :chat_models, -> { where(model_type: "chat") }
    scope :embedding_models, -> { where(model_type: "embedding") }
    scope :image_models, -> { where(model_type: "image") }
    scope :audio_models, -> { where(model_type: "audio") }
    scope :for_provider, ->(provider) { where(provider: provider) }
    scope :with_vision, -> { where(supports_vision: true) }
    scope :with_functions, -> { where(supports_functions: true) }
    scope :by_family, ->(family) { where(family: family) }

    class << self
      def refresh_from_ruby_llm!
        raise_if_ruby_llm_not_available!

        # Refresh models from providers
        RubyLLM.models.refresh!

        # Get all models from RubyLLM
        models_data = RubyLLM.models.all

        imported_count = 0
        models_data.each do |model|
          record = find_or_initialize_by(model_id: model.id)
          is_new_record = record.new_record?

          record.assign_attributes(
            provider: model.provider,
            model_type: model.type,
            name: model.name || model.id,
            family: model.family,
            context_window: model.context_window,
            max_tokens: model.max_tokens,
            supports_vision: model.supports_vision? || false,
            supports_functions: model.supports_functions? || false,
            input_price_per_million: model.input_price_per_million,
            output_price_per_million: model.output_price_per_million
          )

          # Only set active: true for new models, preserve existing state
          record.active = true if is_new_record

          if record.save
            imported_count += 1
          else
            Rails.logger.warn "Failed to save AI model #{model.id}: #{record.errors.full_messages.join(', ')}"
          end
        end

        imported_count
      end

      def text_models_for_providers(providers)
        active.chat_models.where(provider: providers).order(:name)
      end

      def image_models_for_providers(providers)
        active.image_models.where(provider: providers).order(:name)
      end

      def vision_models_for_providers(providers)
        active.chat_models.with_vision.where(provider: providers).order(:name)
      end

      private

      def raise_if_ruby_llm_not_available!
        return if AiConfiguration.ruby_llm_available?

        raise LoadError, "RubyLLM gem is not available. Add 'ruby_llm' to your Gemfile."
      end
    end

    def display_name
      name.presence || model_id
    end

    def price_info
      return nil if input_price_per_million.nil? && output_price_per_million.nil?

      parts = []
      parts << "$#{input_price_per_million}/M in" if input_price_per_million
      parts << "$#{output_price_per_million}/M out" if output_price_per_million
      parts.join(" / ")
    end

    def as_json_for_editor
      {
        id: model_id,
        name: display_name,
        provider: provider,
        type: model_type,
        supports_vision: supports_vision,
        supports_functions: supports_functions,
        context_window: context_window,
        max_tokens: max_tokens
      }
    end
  end
end
