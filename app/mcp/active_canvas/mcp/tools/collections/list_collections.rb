module ActiveCanvas
  module Mcp
    module Tools
      module Collections
        class ListCollections < BaseTool
          tool_name "list_collections"
          description "List collections (structured content types), with their fields and item counts."
          input_schema(properties: { limit: { type: "integer" }, offset: { type: "integer" } })
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            page = paginate(ActiveCanvas::Collection.order(:name), args)
            items = page[:items].to_a
            counts = ActiveCanvas::CollectionItem.where(collection_id: items.map(&:id)).group(:collection_id).count
            page.merge(items: items.map { |c| Serializers.collection(c, items_count: counts[c.id] || 0) })
          end
        end
      end
    end
  end
end
