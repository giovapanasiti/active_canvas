module ActiveCanvas
  module Mcp
    module Tools
      module Pages
        class GetPage < BaseTool
          tool_name "get_page"
          description "Get a page's full record: metadata, all SEO fields, and content (content, content_css, content_js are HTML; bindings drives dynamic data). Pass id or slug (one is required)."
          input_schema(properties: { id: { type: "integer" }, slug: { type: "string" } })
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            fail!("Provide either id or slug") if args[:id].blank? && args[:slug].blank?

            page = args[:id].present? ? ActiveCanvas::Page.find(args[:id]) : ActiveCanvas::Page.find_by!(slug: args[:slug])
            Serializers.page(page)
          end
        end
      end
    end
  end
end
