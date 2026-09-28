module ActiveCanvas
  module Mcp
    module Tools
      module Settings
        class UpdateSiteSettings < BaseTool
          tool_name "update_site_settings"
          description "Update site-wide settings. Every field is optional; only the fields given are changed. `tailwind_config` must be a JSON object string. `homepage_page_id` must reference an existing page."
          input_schema(properties: {
            homepage_page_id: { type: "integer" },
            global_css: { type: "string" },
            global_js: { type: "string" },
            custom_head_html: { type: "string" },
            tailwind_config: { type: "string" }
          })
          required_scope :publish

          def perform(args)
            update_tailwind_config!(args[:tailwind_config]) if args.key?(:tailwind_config)
            update_homepage_page_id!(args[:homepage_page_id]) if args.key?(:homepage_page_id)
            ActiveCanvas::Setting.global_css = args[:global_css] if args.key?(:global_css)
            ActiveCanvas::Setting.global_js = args[:global_js] if args.key?(:global_js)
            ActiveCanvas::Setting.custom_head_html = args[:custom_head_html] if args.key?(:custom_head_html)

            Serializers.site_settings
          end

          private

          def update_tailwind_config!(raw)
            parsed = JSON.parse(raw.to_s)
            fail!("tailwind_config must be a JSON object") unless parsed.is_a?(Hash)
            ActiveCanvas::Setting.tailwind_config = raw
          rescue JSON::ParserError => e
            fail!("tailwind_config must be valid JSON: #{e.message}")
          end

          def update_homepage_page_id!(page_id)
            ActiveCanvas::Page.find(page_id) if page_id.present?
            ActiveCanvas::Setting.homepage_page_id = page_id
          end
        end
      end
    end
  end
end
