module ActiveCanvas
  module Admin
    module CollectionItemsHelper
      # The value shown for an item in the grid: published rows show `data`,
      # drafts show `draft_data`, both read through the schema so removed
      # fields never appear.
      def collection_cell(item, field)
        values = item.status == "published" ? item.data : item.draft_data
        raw_value = (values || {})[field["id"]]

        case field["type"]
        when "boolean" then raw_value ? "✓" : "✗"
        when "media"   then ActiveCanvas::Media.find_by(id: raw_value)&.filename.to_s
        else truncate(raw_value.to_s, length: 40)
        end
      end

      def collection_status_badge(item)
        if item.status == "published"
          tag.span("Published", class: "badge badge-success")
        else
          tag.span("Draft", class: "badge badge-gray")
        end
      end
    end
  end
end
