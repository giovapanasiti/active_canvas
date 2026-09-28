module ActiveCanvas
  module Mcp
    module Tools
      module Ai
        class SetAiModelsActive < BaseTool
          tool_name "set_ai_models_active"
          description "Activate or deactivate one or more AI models. `model_ids` are AiModel `model_id` strings (not database ids), letting you toggle a single model or bulk-toggle several at once."
          input_schema(
            properties: {
              model_ids: { type: "array", items: { type: "string" } },
              active: { type: "boolean" }
            },
            required: %w[model_ids active]
          )
          required_scope :publish

          def perform(args)
            model_ids = Array(args[:model_ids])
            active = ActiveModel::Type::Boolean.new.cast(args[:active])

            models = ActiveCanvas::AiModel.where(model_id: model_ids)
            missing = model_ids - models.pluck(:model_id)
            fail!("Unknown AI model ids: #{missing.join(', ')}") if missing.any?

            { updated: models.update_all(active: active) }
          end
        end
      end
    end
  end
end
