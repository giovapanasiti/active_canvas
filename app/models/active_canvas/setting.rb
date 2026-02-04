module ActiveCanvas
  class Setting < ApplicationRecord
    validates :key, presence: true, uniqueness: true

    CSS_FRAMEWORKS = {
      "tailwind" => {
        name: "Tailwind CSS",
        url: "https://cdn.tailwindcss.com",
        type: :script
      },
      "bootstrap5" => {
        name: "Bootstrap 5",
        url: "https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css",
        type: :stylesheet
      },
      "custom" => {
        name: "Custom CSS (no framework)",
        url: nil,
        type: nil
      }
    }.freeze

    class << self
      def get(key)
        find_by(key: key)&.value
      end

      def set(key, value)
        setting = find_or_initialize_by(key: key)
        setting.update!(value: value)
        value
      end

      def homepage_page_id
        get("homepage_page_id")&.to_i
      end

      def homepage_page_id=(page_id)
        set("homepage_page_id", page_id.presence)
      end

      def homepage
        page_id = homepage_page_id
        return nil unless page_id&.positive?

        Page.published.find_by(id: page_id)
      end

      def css_framework
        get("css_framework") || ActiveCanvas.config.css_framework.to_s
      end

      def css_framework=(framework)
        set("css_framework", framework.presence)
      end

      def css_framework_config
        CSS_FRAMEWORKS[css_framework] || CSS_FRAMEWORKS["custom"]
      end

      def css_framework_url
        css_framework_config[:url]
      end

      def css_framework_type
        css_framework_config[:type]
      end

      def global_css
        get("global_css") || ""
      end

      def global_css=(css)
        set("global_css", css)
      end

      def global_js
        get("global_js") || ""
      end

      def global_js=(js)
        set("global_js", js)
      end

      # AI API Keys
      def ai_openai_api_key
        get("ai_openai_api_key")
      end

      def ai_openai_api_key=(key)
        set("ai_openai_api_key", key.presence)
      end

      def ai_anthropic_api_key
        get("ai_anthropic_api_key")
      end

      def ai_anthropic_api_key=(key)
        set("ai_anthropic_api_key", key.presence)
      end

      def ai_openrouter_api_key
        get("ai_openrouter_api_key")
      end

      def ai_openrouter_api_key=(key)
        set("ai_openrouter_api_key", key.presence)
      end

      # AI Default Models
      def ai_default_text_model
        get("ai_default_text_model") || "gpt-4o-mini"
      end

      def ai_default_text_model=(model)
        set("ai_default_text_model", model.presence)
      end

      def ai_default_image_model
        get("ai_default_image_model") || "dall-e-3"
      end

      def ai_default_image_model=(model)
        set("ai_default_image_model", model.presence)
      end

      def ai_default_vision_model
        get("ai_default_vision_model") || "gpt-4o"
      end

      def ai_default_vision_model=(model)
        set("ai_default_vision_model", model.presence)
      end

      # AI Feature Toggles
      def ai_text_enabled?
        get("ai_text_enabled") != "false"
      end

      def ai_text_enabled=(enabled)
        set("ai_text_enabled", enabled.to_s)
      end

      def ai_image_enabled?
        get("ai_image_enabled") != "false"
      end

      def ai_image_enabled=(enabled)
        set("ai_image_enabled", enabled.to_s)
      end

      def ai_screenshot_enabled?
        get("ai_screenshot_enabled") != "false"
      end

      def ai_screenshot_enabled=(enabled)
        set("ai_screenshot_enabled", enabled.to_s)
      end

      # Tailwind Configuration
      DEFAULT_TAILWIND_CONFIG = {
        theme: {
          extend: {
            colors: {},
            fontFamily: {}
          }
        }
      }.freeze

      def tailwind_compiled_mode?
        css_framework == "tailwind" && ActiveCanvas::TailwindCompiler.available?
      end

      def tailwind_config
        raw = get("tailwind_config")
        return DEFAULT_TAILWIND_CONFIG.deep_dup if raw.blank?

        JSON.parse(raw).deep_symbolize_keys
      rescue JSON::ParserError
        DEFAULT_TAILWIND_CONFIG.deep_dup
      end

      def tailwind_config=(config)
        value = case config
                when String
                  config
                when Hash
                  config.to_json
                else
                  config.to_s
                end
        set("tailwind_config", value)
      end

      def tailwind_config_js
        tailwind_config.to_json
      end
    end
  end
end
