module ActiveCanvas
  module Mcp
    module Tools
      module CollectionItems
        class CreateCollectionItem < BaseTool
          tool_name "create_collection_item"
          description "Create a collection item as a draft. `data` is a Hash of field id => value, coerced per the collection's schema; unknown keys are dropped. A `rich_text` field's value is Action Text HTML (may include <action-text-attachment sgid=\"...\"> tags). `seo` is { meta_title, meta_description, og_image_media_id }, all optional; each falls back to a schema field (see the collection's title_field/description_field/image_field) when blank."
          input_schema(
            properties: {
              collection_id: { type: "integer" },
              slug: { type: "string" },
              data: { type: "object" },
              seo: { type: "object" }
            },
            required: [ "collection_id" ]
          )
          required_scope :write

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:collection_id])
            item = collection.items.new(slug: args[:slug])
            item.assign_fields(fields_with_seo(args))
            item.save!
            Serializers.collection_item(item)
          end
        end
      end
    end
  end
end
