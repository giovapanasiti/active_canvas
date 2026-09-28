module ActiveCanvas
  module Mcp
    module Tools
      module PageTypes
        class ListPageTypes < BaseTool
          tool_name "list_page_types"
          description "List page types (templates that group pages). Returns id, name, key and page count."
          input_schema(properties: { limit: { type: "integer" }, offset: { type: "integer" } })
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            page = paginate(ActiveCanvas::PageType.order(:name), args)
            items = page[:items].to_a
            counts = ActiveCanvas::Page.where(page_type_id: items.map(&:id)).group(:page_type_id).count
            page.merge(items: items.map { |pt| Serializers.page_type(pt, pages_count: counts[pt.id] || 0) })
          end
        end
      end
    end
  end
end
