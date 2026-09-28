module ActiveCanvas
  module Mcp
    module Tools
      module Collections
        class CreateCollection < BaseTool
          # `has_pages` and friends make the collection's items public pages (Part 6);
          # a brand-new collection has no items yet, so turning it on here never needs
          # the 'publish' scope the way update_collection's toggle sometimes does.
          ATTRIBUTES = %i[name slug fields has_pages per_page show_in_sidebar title_field description_field image_field].freeze

          tool_name "create_collection"
          description "Create a collection. `slug` is derived from `name` when omitted. `fields` is an array of { id?, label, type, required?, options? } — id is derived from label when omitted; type is one of text, textarea, rich_text, number, boolean, date, select, media. `has_pages` gives the collection public index/show pages (with their own `per_page`, `show_in_sidebar`, `title_field`, `description_field`, `image_field`); its two template pages are created automatically."
          input_schema(
            properties: {
              name: { type: "string" },
              slug: { type: "string" },
              fields: { type: "array", items: { type: "object" } },
              has_pages: { type: "boolean" },
              per_page: { type: "integer" },
              show_in_sidebar: { type: "boolean" },
              title_field: { type: "string" },
              description_field: { type: "string" },
              image_field: { type: "string" }
            },
            required: [ "name", "fields" ]
          )
          required_scope :write

          def perform(args)
            Serializers.collection(ActiveCanvas::Collection.create!(args.slice(*ATTRIBUTES)))
          end
        end
      end
    end
  end
end
