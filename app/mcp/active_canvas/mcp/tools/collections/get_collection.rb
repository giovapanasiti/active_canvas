module ActiveCanvas
  module Mcp
    module Tools
      module Collections
        class GetCollection < BaseTool
          tool_name "get_collection"
          description "Get one collection by id or slug, with its fields and item count."
          input_schema(properties: { id: { type: "integer" }, slug: { type: "string" } })
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            fail!("id or slug is required") if args[:id].blank? && args[:slug].blank?

            collection = args[:id].present? ? ActiveCanvas::Collection.find(args[:id]) : ActiveCanvas::Collection.find_by!(slug: args[:slug])
            Serializers.collection(collection)
          end
        end
      end
    end
  end
end
