module ActiveCanvas
  module Mcp
    module Tools
      module PageTypes
        class UpdatePageType < BaseTool
          tool_name "update_page_type"
          description "Update a page type's name and/or key."
          input_schema(
            properties: { id: { type: "integer" }, name: { type: "string" }, key: { type: "string" } },
            required: [ "id" ]
          )
          required_scope :write

          def perform(args)
            page_type = ActiveCanvas::PageType.find(args[:id])
            page_type.update!(args.slice(:name, :key))
            Serializers.page_type(page_type)
          end
        end
      end
    end
  end
end
