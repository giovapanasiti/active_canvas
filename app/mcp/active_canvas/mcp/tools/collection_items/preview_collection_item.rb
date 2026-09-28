module ActiveCanvas
  module Mcp
    module Tools
      module CollectionItems
        class PreviewCollectionItem < BaseTool
          MAX_BYTES = 500_000

          tool_name "preview_collection_item"
          description "Render the collection's show template page with this item's DRAFT data (nothing is saved). html is truncated at 500 KB (truncated: true when it was)."
          input_schema(
            properties: { collection_id: { type: "integer" }, id: { type: "integer" } },
            required: [ "collection_id", "id" ]
          )
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:collection_id])
            item = collection.items.find(args[:id])

            html = ActiveCanvas::CollectionItemPreview.call(item)[:html]
            truncated = html.bytesize > MAX_BYTES
            html = html.byteslice(0, MAX_BYTES).scrub if truncated

            { html: html, truncated: truncated }
          end
        end
      end
    end
  end
end
