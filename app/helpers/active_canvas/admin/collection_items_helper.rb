module ActiveCanvas
  module Admin
    module CollectionItemsHelper
      # The value shown for an item in the grid, read through the schema so
      # removed fields never appear.
      def collection_cell(item, field)
        raw_value = item.effective_data[field["id"]]

        case field["type"]
        when "boolean" then raw_value ? "✓" : "✗"
        when "media"   then media_filenames[raw_value.to_i].to_s
        else truncate(raw_value.to_s, length: 40)
        end
      end

      def collection_status_badge(item)
        if item.status != "published"
          tag.span("Draft", class: "badge badge-gray")
        elsif item.pending_changes?
          tag.span("Published · draft changes", class: "badge badge-warning")
        else
          tag.span("Published", class: "badge badge-success")
        end
      end

      private

      def media_filenames
        @media_filenames ||= ActiveCanvas::Media.pluck(:id, :filename).to_h
      end
    end
  end
end
