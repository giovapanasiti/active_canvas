module ActiveCanvas
  module Mcp
    module Tools
      module CollectionItems
        class UpdateCollectionItem < BaseTool
          tool_name "update_collection_item"
          description "Update a collection item's slug and/or draft data. Only the draft changes — the published snapshot changes only on publish. Requires the 'publish' scope in addition to 'write' when the item is currently published."
          input_schema(
            properties: {
              collection_id: { type: "integer" },
              id: { type: "integer" },
              slug: { type: "string" },
              data: { type: "object" }
            },
            required: [ "collection_id", "id" ]
          )
          required_scope :write

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:collection_id])
            item = collection.items.find(args[:id])
            require_publish_if_published!(item, "collection item")

            item.slug = args[:slug] if args.key?(:slug)
            item.assign_fields(args[:data]) if args.key?(:data)
            item.save!
            Serializers.collection_item(item)
          end
        end
      end
    end
  end
end
