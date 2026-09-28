module ActiveCanvas
  module Mcp
    module Tools
      module Collections
        class CreateCollection < BaseTool
          tool_name "create_collection"
          description "Create a collection. `slug` is derived from `name` when omitted. `fields` is an array of { id?, label, type, required?, options? } — id is derived from label when omitted; type is one of text, textarea, rich_text, number, boolean, date, select, media."
          input_schema(
            properties: {
              name: { type: "string" },
              slug: { type: "string" },
              fields: { type: "array", items: { type: "object" } }
            },
            required: [ "name", "fields" ]
          )
          required_scope :write

          def perform(args)
            Serializers.collection(ActiveCanvas::Collection.create!(args.slice(:name, :slug, :fields)))
          end
        end
      end
    end
  end
end
