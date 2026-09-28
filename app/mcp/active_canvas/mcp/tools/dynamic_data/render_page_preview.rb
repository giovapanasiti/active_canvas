module ActiveCanvas
  module Mcp
    module Tools
      module DynamicData
        class RenderPagePreview < BaseTool
          MAX_BYTES = 500_000

          tool_name "render_page_preview"
          description "Render a complete HTML page (layout, partials, CSS framework) from the page's saved state with optional unsaved overrides for content/content_css/content_js/bindings/template_enabled — nothing is saved. `bindings` may be a JSON object or a JSON-encoded string. html is truncated at 500 KB (truncated: true when it was)."
          input_schema(
            properties: {
              page_id: { type: "integer" },
              content: { type: "string" },
              content_css: { type: "string" },
              content_js: { type: "string" },
              bindings: {},
              template_enabled: { type: "boolean" }
            },
            required: [ "page_id" ]
          )
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            page = ActiveCanvas::Page.find(args[:page_id])
            bindings = args.key?(:bindings) ? parse_bindings(args[:bindings]) : nil
            template_enabled = args.key?(:template_enabled) ? ActiveModel::Type::Boolean.new.cast(args[:template_enabled]) : nil

            result = ActiveCanvas::PagePreview.call(
              page,
              content: args[:content]&.to_s, content_css: args[:content_css]&.to_s, content_js: args[:content_js]&.to_s,
              bindings: bindings, template_enabled: template_enabled
            )
            fail!(result[:error][:message]) if result[:error]

            html = result[:html]
            truncated = html.bytesize > MAX_BYTES
            html = html.byteslice(0, MAX_BYTES).scrub if truncated

            { html: html, truncated: truncated }
          end
        end
      end
    end
  end
end
