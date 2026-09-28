module ActiveCanvas
  module Mcp
    module Tools
      module Collections
        class UpdateCollection < BaseTool
          tool_name "update_collection"
          description "Update a collection's name, slug and/or fields. `fields`, when given, replaces the whole array."
          input_schema(
            properties: {
              id: { type: "integer" },
              name: { type: "string" },
              slug: { type: "string" },
              fields: { type: "array", items: { type: "object" } }
            },
            required: [ "id" ]
          )
          required_scope :write

          def perform(args)
            collection = ActiveCanvas::Collection.find(args[:id])
            collection.update!(args.slice(:name, :slug, :fields))
            Serializers.collection(collection)
          end
        end
      end
    end
  end
end
