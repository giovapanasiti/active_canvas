module ActiveCanvas
  module Mcp
    module Tools
      module Pages
        class UpdatePageContent < BaseTool
          CONTENT_KEYS = %i[content content_css content_js template_enabled bindings].freeze

          tool_name "update_page_content"
          description "Update a page's content (HTML), content_css, content_js, template_enabled and/or bindings. Requires the 'publish' scope in addition to 'write' when the page is currently published. When the page ends up template_enabled, content is validated as Liquid before saving; invalid Liquid is rejected with its line/column and nothing is saved."
          input_schema(
            properties: {
              id: { type: "integer" },
              content: { type: "string" },
              content_css: { type: "string" },
              content_js: { type: "string" },
              template_enabled: { type: "boolean" },
              bindings: {}
            },
            required: [ "id" ]
          )
          required_scope :write

          def perform(args)
            page = ActiveCanvas::Page.find(args[:id])
            require_publish_if_published!(page, "page")

            result = ActiveCanvas::PageContentUpdate.call(page, args.slice(*CONTENT_KEYS))
            fail!(content_update_error(result)) unless result.success?

            { page: Serializers.page(page.reload), version_number: page.current_version_number, tailwind: result.tailwind }
          end
        end
      end
    end
  end
end
