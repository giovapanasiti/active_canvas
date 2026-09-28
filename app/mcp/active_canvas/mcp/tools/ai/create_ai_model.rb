module ActiveCanvas
  module Mcp
    module Tools
      module Ai
        class CreateAiModel < BaseTool
          tool_name "create_ai_model"
          description "Manually register an AI model (e.g. one not returned by sync_ai_models). model_id and provider are required."
          input_schema(
            properties: {
              model_id: { type: "string" },
              provider: { type: "string" },
              model_type: { type: "string" },
              name: { type: "string" },
              context_window: { type: "integer" },
              max_tokens: { type: "integer" },
              supports_functions: { type: "boolean" },
              active: { type: "boolean" },
              input_modalities: { type: "array", items: { type: "string" } },
              output_modalities: { type: "array", items: { type: "string" } }
            },
            required: %w[model_id provider]
          )
          required_scope :publish

          def perform(args)
            model = ActiveCanvas::AiModel.create_from_params!(build_params(args))
            model.as_json_for_editor.merge(active: model.active)
          end

          private

          def build_params(args)
            params = args.slice(:model_id, :provider, :model_type, :name, :context_window, :max_tokens,
                                 :input_modalities, :output_modalities)
            params[:supports_functions] = flag(args[:supports_functions])
            params[:active] = args.key?(:active) ? flag(args[:active]) : "1"
            params
          end

          def flag(value)
            ActiveModel::Type::Boolean.new.cast(value) ? "1" : "0"
          end
        end
      end
    end
  end
end
