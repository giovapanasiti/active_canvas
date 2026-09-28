module ActiveCanvas
  module Mcp
    module Tools
      module Pages
        class SetPagePublished < BaseTool
          tool_name "set_page_published"
          description "Publish or unpublish a page. Requires the 'publish' scope."
          input_schema(properties: { id: { type: "integer" }, published: { type: "boolean" } }, required: [ "id", "published" ])
          annotations(destructive_hint: true, idempotent_hint: true)
          required_scope :publish

          def perform(args)
            page = ActiveCanvas::Page.find(args[:id])
            page.update!(published: ActiveModel::Type::Boolean.new.cast(args[:published]))
            Serializers.page(page)
          end
        end
      end
    end
  end
end
