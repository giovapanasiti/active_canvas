module ActiveCanvas
  module Mcp
    module Tools
      module Partials
        class ListPartials < BaseTool
          tool_name "list_partials"
          description "List the header and footer partials, creating them first if they don't exist yet."
          input_schema(properties: { limit: { type: "integer" }, offset: { type: "integer" } })
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            ActiveCanvas::Partial.ensure_defaults!

            page = paginate(ActiveCanvas::Partial.order(:partial_type), args)
            page.merge(items: page[:items].map { |p| Serializers.partial(p) })
          end
        end
      end
    end
  end
end
