module ActiveCanvas
  module Mcp
    module Tools
      module Forms
        class GetFormSubmission < BaseTool
          tool_name "get_form_submission"
          description "Get one form submission by id."
          input_schema(properties: { id: { type: "integer" } }, required: [ "id" ])
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            Serializers.form_submission(ActiveCanvas::FormSubmission.find(args[:id]))
          end
        end
      end
    end
  end
end
