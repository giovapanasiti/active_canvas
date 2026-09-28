module ActiveCanvas
  module Mcp
    module Tools
      module Ai
        class ListAiModels < BaseTool
          tool_name "list_ai_models"
          description "List AI models known to the server (synced from providers or added manually). Excludes inactive models unless include_inactive is true."
          input_schema(properties: {
            include_inactive: { type: "boolean" },
            limit: { type: "integer" },
            offset: { type: "integer" }
          })
          annotations(read_only_hint: true)
          required_scope :read

          def perform(args)
            include_inactive = ActiveModel::Type::Boolean.new.cast(args[:include_inactive])
            relation = include_inactive ? ActiveCanvas::AiModel.all : ActiveCanvas::AiModel.active

            page = paginate(relation.order(:provider, :model_id), args)
            page.merge(items: page[:items].map { |m| m.as_json_for_editor.merge(active: m.active) })
          end
        end
      end
    end
  end
end
