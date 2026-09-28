module ActiveCanvas
  module Mcp
    module Tools
      module Settings
        class GetSettings < BaseTool
          tool_name "get_settings"
          description "Get the site's global settings (homepage, CSS framework, global CSS/JS, custom head HTML, tailwind config), SEO settings, and AI configuration. API keys are always masked."
          input_schema(properties: {})
          annotations(read_only_hint: true)
          required_scope :read

          def perform(_args)
            Serializers.site_settings.merge(seo: Serializers.seo_settings, ai: Serializers.ai_settings)
          end
        end
      end
    end
  end
end
