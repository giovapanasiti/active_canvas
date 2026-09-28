module ActiveCanvas
  module Mcp
    module Tools
      module Ai
        class SyncAiModels < BaseTool
          tool_name "sync_ai_models"
          description "Refresh the known AI model list from configured providers. Requires at least one API key to be configured."
          input_schema(properties: {})
          required_scope :publish

          def perform(_args)
            fail!("AI not configured. Add API keys in Settings > AI.") unless ActiveCanvas::AiConfiguration.configured?

            { synced: refresh! }
          end

          private

          def refresh!
            ActiveCanvas::AiModels.refresh!
          rescue StandardError => e
            # See generate_image's identical rationale: log the provider's raw message, never
            # return it to the caller.
            Rails.logger.warn("[ActiveCanvas::Mcp] sync_ai_models failed: #{e.class}: #{e.message}")
            fail!("Model sync failed (#{e.class})")
          end
        end
      end
    end
  end
end
