module ActiveCanvas
  module Mcp
    module Tools
      module CollectionItems
        class ListCollectionItems < BaseTool
          tool_name "list_collection_items"
          description "List a collection's items, most recently updated first. `status`, if given, must be 'draft' or 'published'. Each item's `fields` holds the first 4 schema fields' effective values, keyed by field id."
          input_schema(
            properties: {
              collection_id: { type: "integer" },
              status: { type: "string" },
              limit: { type: "integer" },
              offset: { type: "integer" }
            },
            required: [ "collection_id" ]
          )
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:collection_id])
            relation = collection.items.order(updated_at: :desc)

            if args[:status].present?
              fail!("status must be 'draft' or 'published'") unless %w[draft published].include?(args[:status])
              relation = relation.where(status: args[:status])
            end

            page = paginate(relation, args)
            page.merge(items: page[:items].map { |i| Serializers.collection_item_summary(i) })
          end
        end
      end
    end
  end
end
