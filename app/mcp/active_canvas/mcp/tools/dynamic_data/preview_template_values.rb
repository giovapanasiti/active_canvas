module ActiveCanvas
  module Mcp
    module Tools
      module DynamicData
        class PreviewTemplateValues < BaseTool
          tool_name "preview_template_values"
          description "What each chip in unsaved content displays with unsaved bindings: the text each {{ }} shows in its first occurrence (values), and for every loop/condition element how it renders (loops, conds). `bindings` may be a JSON object or a JSON-encoded string. On a collection's template page, its implicit item/items/collection/pagination assigns are applied automatically."
          input_schema(
            properties: { page_id: { type: "integer" }, content: { type: "string" }, bindings: {} },
            required: [ "page_id", "content" ]
          )
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            page = ActiveCanvas::Page.find(args[:page_id])
            result = ActiveCanvas::TemplateChipValues.call(
              page, content: args[:content].to_s, bindings: parse_bindings(args[:bindings]),
              context: ActiveCanvas::TemplateEditorContext.live(page)
            )
            result.body
          end
        end
      end
    end
  end
end
