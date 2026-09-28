module ActiveCanvas
  module Mcp
    module Tools
      module DynamicData
        class ValidateTemplate < BaseTool
          tool_name "validate_template"
          description "Run unsaved content/bindings through the strict preview renderer and report the first Liquid error with its line/column, without saving anything. Returns { ok: true } or { ok: false, error: { message, line, column } } — a validation failure is a normal result, not a tool error. `bindings` may be a JSON object or a JSON-encoded string."
          input_schema(
            properties: { page_id: { type: "integer" }, content: { type: "string" }, bindings: {} },
            required: [ "page_id", "content" ]
          )
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            page = ActiveCanvas::Page.find(args[:page_id])
            ActiveCanvas::TemplateValidation.call(page, content: args[:content].to_s, bindings: parse_bindings(args[:bindings]))
          end
        end
      end
    end
  end
end
