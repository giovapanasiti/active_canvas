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
            template_page_ids = template_page_ids_for(items)
            page.merge(items: items.map { |c| Serializers.collection(c, items_count: counts[c.id] || 0, template_page_ids: template_page_ids) })
          end

          private

          # One query for every has_pages collection's template pages, shaped like
          # Serializers.collection expects: { collection_id => { "index" => id, "show" => id } }.
          def template_page_ids_for(items)
            has_pages_ids = items.select(&:has_pages?).map(&:id)
            return {} if has_pages_ids.empty?

            ActiveCanvas::Page.where(collection_id: has_pages_ids).pluck(:collection_id, :collection_role, :id)
              .group_by { |collection_id, _role, _id| collection_id }
              .transform_values { |rows| rows.to_h { |_collection_id, role, id| [ role, id ] } }
          end
        end
      end
    end
  end
end
