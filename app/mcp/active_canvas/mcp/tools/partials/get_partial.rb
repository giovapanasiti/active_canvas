module ActiveCanvas
  module Mcp
    module Tools
      module Partials
        class GetPartial < BaseTool
          tool_name "get_partial"
          description "Fetch a single partial by id or by partial_type (\"header\"/\"footer\")."
          input_schema(
            properties: {
              id: { type: "integer" },
              partial_type: { type: "string", enum: ActiveCanvas::Partial::TYPES }
            }
          )
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            partial =
              if args[:id].present?
                ActiveCanvas::Partial.find(args[:id])
              elsif args[:partial_type].present?
                ActiveCanvas::Partial.find_by!(partial_type: args[:partial_type])
              else
                fail!("id or partial_type is required")
              end

            Serializers.partial(partial)
          end
        end
      end
    end
  end
end
