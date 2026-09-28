module ActiveCanvas
  module Mcp
    module Tools
      module PageTypes
        class DeletePageType < BaseTool
          tool_name "delete_page_type"
          description "Delete a page type. Fails if any page still uses it."
          input_schema(properties: { id: { type: "integer" } }, required: [ "id" ])
          annotations(destructive_hint: true)
          required_scope :write

          def perform(args)
            page_type = ActiveCanvas::PageType.find(args[:id])
            page_type.destroy!
            { deleted: true, id: page_type.id }
          end
        end
      end
    end
  end
end
