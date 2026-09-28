module ActiveCanvas
  module Mcp
    module Tools
      module CollectionItems
        class UnpublishCollectionItem < BaseTool
          tool_name "unpublish_collection_item"
          description "Move a collection item back to draft status. The published snapshot (`data`) is left as-is until the item is published again."
          input_schema(properties: { collection_id: { type: "integer" }, id: { type: "integer" } }, required: [ "collection_id", "id" ])
          annotations(destructive_hint: true)
          required_scope :publish

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:collection_id])
            item = collection.items.find(args[:id])
            item.unpublish!
            Serializers.collection_item(item)
          end
        end
      end
    end
  end
end
