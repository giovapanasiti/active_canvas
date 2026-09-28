module ActiveCanvas
  module Mcp
    module Tools
      module Forms
        class DeleteFormSubmission < BaseTool
          tool_name "delete_form_submission"
          description "Delete a form submission."
          input_schema(properties: { id: { type: "integer" } }, required: [ "id" ])
          annotations(destructive_hint: true)
          required_scope :write

          def perform(args)
            submission = ActiveCanvas::FormSubmission.find(args[:id])
            submission.destroy!
            { deleted: true, id: submission.id }
          end
        end
      end
    end
  end
end
