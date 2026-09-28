module ActiveCanvas
  module Mcp
    module Tools
      module Ai
        class GenerateImage < BaseTool
          tool_name "generate_image"
          description "Generate an image from a text prompt and save it as Media. Requires image generation to be enabled and AI to be configured; rate limited per token."
          input_schema(
            properties: { prompt: { type: "string" }, model: { type: "string" } },
            required: [ "prompt" ]
          )
          required_scope :write

          def perform(args)
            fail!("Image generation is disabled or AI is not configured.") unless ActiveCanvas::AiConfiguration.image_enabled?

            enforce_rate_limit!

            media = ActiveCanvas::AiService.generate_image(prompt: args[:prompt], model: args[:model])
            { media: Serializers.media(media) }
          rescue ToolError
            raise
          rescue StandardError => e
            # The provider's raw message can carry request/response detail (a prompt, an account
            # identifier, an upstream error body) that shouldn't be echoed back through a tool
            # response; log it for operators and surface only the exception class to the caller.
            Rails.logger.warn("[ActiveCanvas::Mcp] generate_image failed: #{e.class}: #{e.message}")
            fail!("Image generation failed (#{e.class})")
          end

          private

          def enforce_rate_limit!
            limit = ActiveCanvas.config.ai_rate_limit_per_minute
            cache_key = "active_canvas:rate_limit:ai:token:#{token.id}"
            count = increment_rate_limit(cache_key)

            fail!("AI rate limit exceeded") if count > limit
          end

          def increment_rate_limit(cache_key)
            if Rails.cache.respond_to?(:increment)
              Rails.cache.increment(cache_key, 1, expires_in: 1.minute, raw: true).to_i
            else
              current = Rails.cache.read(cache_key).to_i
              Rails.cache.write(cache_key, current + 1, expires_in: 1.minute)
              current + 1
            end
          end
        end
      end
    end
  end
end
