module ActiveCanvas
  module Mcp
    module Tools
      module CollectionItems
        class PublishCollectionItem < BaseTool
          tool_name "publish_collection_item"
          description "Copy a collection item's draft into its published snapshot and record a version. Fails listing labels of any required fields left blank."
          input_schema(properties: { collection_id: { type: "integer" }, id: { type: "integer" } }, required: [ "collection_id", "id" ])
          required_scope :publish

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:collection_id])
            item = collection.items.find(args[:id])

            unless item.publish
              schema = ActiveCanvas::CollectionSchema.new(collection.fields)
              missing = schema.missing_required_labels(schema.coerce_all_for_storage(item.draft_data))
              fail!("Missing required fields: #{missing.join(", ")}")
            end

            Serializers.collection_item(item)
          end
        end
      end
    end
  end
end
