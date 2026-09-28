module ActiveCanvas
  module Mcp
    module Tools
      module Ai
        class UpdateAiSettings < BaseTool
          tool_name "update_ai_settings"
          description "Update AI configuration: API keys, default models, connection mode, and feature toggles. Every field is optional; a masked API key value (starting with '****') is ignored so a round-tripped display value never overwrites the real key. Keys are never returned unmasked."
          input_schema(properties: {
            openai_api_key: { type: "string" },
            anthropic_api_key: { type: "string" },
            openrouter_api_key: { type: "string" },
            default_text_model: { type: "string" },
            default_image_model: { type: "string" },
            default_vision_model: { type: "string" },
            text_enabled: { type: "boolean" },
            image_enabled: { type: "boolean" },
            screenshot_enabled: { type: "boolean" }
          })
          required_scope :publish

          # Maps the MCP tool's input names to the `Setting`-prefixed param
          # names ActiveCanvas::AiSettingsUpdate expects.
          PARAM_MAPPING = {
            openai_api_key: :ai_openai_api_key,
            anthropic_api_key: :ai_anthropic_api_key,
            openrouter_api_key: :ai_openrouter_api_key,
            default_text_model: :ai_default_text_model,
            default_image_model: :ai_default_image_model,
            default_vision_model: :ai_default_vision_model,
            text_enabled: :ai_text_enabled,
            image_enabled: :ai_image_enabled,
            screenshot_enabled: :ai_screenshot_enabled
          }.freeze

          def perform(args)
            params = {}
            PARAM_MAPPING.each do |mcp_key, setting_key|
              params[setting_key] = args[mcp_key] if args.key?(mcp_key)
            end

            ActiveCanvas::AiSettingsUpdate.call(params)

            Serializers.ai_settings
          end
        end
      end
    end
  end
end
