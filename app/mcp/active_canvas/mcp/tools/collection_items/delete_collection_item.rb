module ActiveCanvas
  module Mcp
    module Tools
      module CollectionItems
        class DeleteCollectionItem < BaseTool
          tool_name "delete_collection_item"
          description "Delete a collection item. Requires the 'publish' scope in addition to 'write' when the item is currently published."
          input_schema(properties: { collection_id: { type: "integer" }, id: { type: "integer" } }, required: [ "collection_id", "id" ])
          annotations(destructive_hint: true)
          required_scope :write

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:collection_id])
            item = collection.items.find(args[:id])
            require_publish_if_published!(item, "collection item")

            item.destroy!
            { deleted: true, id: item.id }
          end
        end
      end
    end
  end
end
