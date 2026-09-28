module ActiveCanvas
  module Mcp
    module Tools
      module CollectionItems
        class GetCollectionItem < BaseTool
          tool_name "get_collection_item"
          description "Get one collection item: its published snapshot (`data`), its draft (`draft_data`), and status."
          input_schema(properties: { collection_id: { type: "integer" }, id: { type: "integer" } }, required: [ "collection_id", "id" ])
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:collection_id])
            Serializers.collection_item(collection.items.find(args[:id]))
          end
        end
      end
    end
  end
end
