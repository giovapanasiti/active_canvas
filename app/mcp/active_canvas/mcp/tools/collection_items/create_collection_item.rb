module ActiveCanvas
  module Mcp
    module Tools
      module CollectionItems
        class CreateCollectionItem < BaseTool
          tool_name "create_collection_item"
          description "Create a collection item as a draft. `data` is a Hash of field id => value, coerced per the collection's schema; unknown keys are dropped."
          input_schema(
            properties: {
              collection_id: { type: "integer" },
              slug: { type: "string" },
              data: { type: "object" }
            },
            required: [ "collection_id" ]
          )
          required_scope :write

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:collection_id])
            item = collection.items.new(slug: args[:slug])
            item.assign_fields(args[:data] || {})
            item.save!
            Serializers.collection_item(item)
          end
        end
      end
    end
  end
end
