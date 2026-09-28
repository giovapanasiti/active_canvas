module ActiveCanvas
  module Mcp
    module Tools
      module Ai
        class GetAiStatus < BaseTool
          tool_name "get_ai_status"
          description "Get AI configuration status: whether AI is configured, which providers have API keys, and which features (text/image/screenshot) are enabled."
          input_schema(properties: {})
          annotations(read_only_hint: true)
          required_scope :read

          def perform(_args)
            ActiveCanvas::AiConfiguration.status_payload
          end
        end
      end
    end
  end
end
