module ActiveCanvas
  # Applies AI settings changes: API keys (skipping blank/masked values so a
  # round-tripped masked display value never overwrites the real key),
  # default models, connection mode, and the three feature toggles. Used by
  # Admin::SettingsController#update_ai and the `update_ai_settings` MCP tool.
  #
  # `params` only needs #key? and #[]; an ActionController::Parameters or a
  # plain Hash both work. Every field is optional and applied only when its
  # key is present, so a partial MCP update never clobbers the rest.
  class AiSettingsUpdate
    MASK_PREFIX = "****".freeze

    MODEL_KEYS = %i[ai_default_text_model ai_default_image_model ai_default_vision_model].freeze
    TOGGLE_KEYS = %i[ai_text_enabled ai_image_enabled ai_screenshot_enabled].freeze
    API_KEYS = %i[ai_openai_api_key ai_anthropic_api_key ai_openrouter_api_key].freeze

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @params = params
    end

    def call
      API_KEYS.each { |key| update_api_key(key, @params[key]) }
      MODEL_KEYS.each { |key| Setting.public_send("#{key}=", @params[key]) if @params.key?(key) }
      Setting.ai_connection_mode = @params[:ai_connection_mode] if @params.key?(:ai_connection_mode)
      TOGGLE_KEYS.each { |key| Setting.public_send("#{key}=", boolean(@params[key])) if @params.key?(key) }

      true
    end

    private

    def update_api_key(key, value)
      return if value.blank?
      return if value.to_s.start_with?(MASK_PREFIX) # Masked value, don't update

      Setting.set(key.to_s, value)
    end

    # ActiveModel::Type::Boolean.new.cast(nil) (and cast("")) is nil, not false: stored via
    # Setting's `enabled.to_s` that becomes "" and reads back as enabled (`get(...) != "false"`).
    # An MCP `update_ai_settings` call that omits a toggle never reaches here at all (the caller
    # only applies keys present in args), so an explicit nil/"" here is a deliberate "turn this
    # off" and must resolve to false, never silently to "enabled".
    def boolean(value)
      ActiveModel::Type::Boolean.new.cast(value) == true
    end
  end
end
