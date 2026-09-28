module ActiveCanvas
  module Mcp
    module Tools
      module CollectionItems
        class GetCollectionItemHistory < BaseTool
          tool_name "get_collection_item_history"
          description "List a collection item's publish history, newest first: version_number, changed_by, change_summary and the published data snapshot at that version."
          input_schema(properties: { collection_id: { type: "integer" }, id: { type: "integer" } }, required: [ "collection_id", "id" ])
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:collection_id])
            item = collection.items.find(args[:id])
            { versions: item.versions.order(version_number: :desc).map { |v| Serializers.collection_item_version(v) } }
          end
        end
      end
    end
  end
end
