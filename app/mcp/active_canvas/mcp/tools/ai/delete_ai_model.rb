module ActiveCanvas
  module Mcp
    module Tools
      module Ai
        class DeleteAiModel < BaseTool
          tool_name "delete_ai_model"
          description "Delete a registered AI model by its model_id."
          input_schema(properties: { model_id: { type: "string" } }, required: [ "model_id" ])
          annotations(destructive_hint: true)
          required_scope :publish

          def perform(args)
            model = ActiveCanvas::AiModel.find_by!(model_id: args[:model_id])
            model.destroy!
            { deleted: true, model_id: model.model_id }
          end
        end
      end
    end
  end
end
