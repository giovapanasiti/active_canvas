module ActiveCanvas
  module Mcp
    module Tools
      module PageTypes
        class CreatePageType < BaseTool
          tool_name "create_page_type"
          description "Create a page type. `key` is derived from `name` when omitted."
          input_schema(properties: { name: { type: "string" }, key: { type: "string" } }, required: [ "name" ])
          required_scope :write

          def perform(args)
            Serializers.page_type(ActiveCanvas::PageType.create!(args.slice(:name, :key)))
          end
        end
      end
    end
  end
end
