module ActiveCanvas
  class AiModel < ApplicationRecord
    validates :model_id, presence: true, uniqueness: true
    validates :provider, presence: true

    serialize :input_modalities, coder: JSON
    serialize :output_modalities, coder: JSON

    scope :active, -> { where(active: true) }
    scope :for_provider, ->(provider) { where(provider: provider) }
    scope :with_functions, -> { where(supports_functions: true) }
    scope :by_family, ->(family) { where(family: family) }

    # Modality-based scopes
    scope :with_text_output,  -> { where("output_modalities LIKE ?", '%"text"%') }
    scope :with_image_output, -> { where("output_modalities LIKE ?", '%"image"%') }
    scope :with_text_input,   -> { where("input_modalities LIKE ?", '%"text"%') }
    scope :with_image_input,  -> { where("input_modalities LIKE ?", '%"image"%') }

    # Convenience scopes matching old names
    scope :text_models,   -> { with_text_output }
    scope :image_models,  -> { with_text_input.with_image_output }
    scope :vision_models, -> { with_text_input.with_image_input.with_text_output }

    # Keep these for display grouping in settings
    scope :chat_models,      -> { where(model_type: "chat") }
    scope :embedding_models, -> { where(model_type: "embedding") }
    scope :audio_models,     -> { where(model_type: "audio") }

    MODALITY_MAP = {
      "chat"      => { input: %w[text],  output: %w[text] },
      "image"     => { input: %w[text],  output: %w[image] },
      "embedding" => { input: %w[text],  output: %w[embedding] },
      "audio"     => { input: %w[text],  output: %w[audio] }
    }.freeze

    class << self
      def refresh_from_ruby_llm!
        raise_if_ruby_llm_not_available!

        RubyLLM.models.refresh!

        models_data = RubyLLM.models.all

        imported_count = 0
        models_data.each do |model|
          record = find_or_initialize_by(model_id: model.id)
          is_new_record = record.new_record?

          modalities = derive_modalities(model.type, model.supports_vision?)

          record.assign_attributes(
            provider: model.provider,
            model_type: model.type,
            name: model.name || model.id,
            family: model.family,
            context_window: model.context_window,
            max_tokens: model.max_tokens,
            input_modalities: modalities[:input],
            output_modalities: modalities[:output],
            supports_functions: model.supports_functions? || false,
            input_price_per_million: model.input_price_per_million,
            output_price_per_million: model.output_price_per_million
          )

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
        active.text_models.where(provider: providers).order(:name)
      end

      def image_models_for_providers(providers)
        active.image_models.where(provider: providers).order(:name)
      end

      def vision_models_for_providers(providers)
        active.vision_models.where(provider: providers).order(:name)
      end

      private

      def derive_modalities(type, vision)
        base = MODALITY_MAP.fetch(type.to_s, { input: %w[text], output: %w[text] })
        input = vision ? (base[:input] | %w[image]) : base[:input]
        { input: input, output: base[:output] }
      end

      def raise_if_ruby_llm_not_available!
        # return if AiConfiguration.ruby_llm_available?

        # raise LoadError, "RubyLLM gem is not available. Add 'ruby_llm' to your Gemfile."
      end
    end

    def display_name
      name.presence || model_id
    end

    def supports_vision?
      input_modalities&.include?("image")
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
        input_modalities: input_modalities,
        output_modalities: output_modalities,
        supports_functions: supports_functions,
        context_window: context_window,
        max_tokens: max_tokens
      }
    end
  end
end
