module ActiveCanvas
  module Mcp
    module Tools
      module DynamicData
        class SampleBindingData < BaseTool
          DEFAULT_LIMIT = 3
          MAX_LIMIT = 20

          tool_name "sample_binding_data"
          description "First rows of one binding, resolved from the given (possibly unsaved) bindings — lets an agent see which field names exist before writing {{ }}. `bindings` may be a JSON object or a JSON-encoded string. Omit page_id to sample against a fresh, unsaved page of the default page type. `limit` defaults to 3, max 20."
          input_schema(
            properties: {
              page_id: { type: "integer" },
              bindings: {},
              binding: { type: "string" },
              limit: { type: "integer" }
            },
            required: [ "bindings", "binding" ]
          )
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            page = args[:page_id].present? ? ActiveCanvas::Page.find(args[:page_id]) : default_page
            limit = (args[:limit] || DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)

            result = ActiveCanvas::BindingSampler.call(
              page, bindings: parse_bindings(args[:bindings]), binding: args[:binding].to_s, rows: limit
            )
            fail!(result.error) if result.error
            { rows: result.rows }
          end

          private

          def default_page
            ActiveCanvas::Page.new(page_type: ActiveCanvas::PageType.default)
          end
        end
      end
    end
  end
end
