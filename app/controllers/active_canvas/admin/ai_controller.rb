module ActiveCanvas
  module Admin
    class AiController < ApplicationController
      include ActionController::Live

      skip_forgery_protection only: %i[ chat ]
      before_action :ensure_ai_configured, except: %i[ status models ]

      def chat
        unless AiConfiguration.text_enabled?
          return render json: { error: "Text generation is disabled" }, status: :forbidden
        end

        response.headers["Content-Type"] = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        response.headers["X-Accel-Buffering"] = "no"

        begin
          AiService.generate_text(
            prompt: params[:prompt],
            model: params[:model],
            context: build_context
          ) do |chunk|
            write_sse_event("chunk", { content: chunk.content })
          end

          write_sse_event("done", {})
        rescue => e
          Rails.logger.error "AI Chat Error: #{e.message}"
          write_sse_event("error", { error: e.message })
        ensure
          response.stream.close
        end
      end

      def image
        unless AiConfiguration.image_enabled?
          return render json: { error: "Image generation is disabled" }, status: :forbidden
        end

        media = AiService.generate_image(
          prompt: params[:prompt],
          model: params[:model]
        )

        render json: {
          success: true,
          image: media.as_json_for_editor,
          url: media.url
        }
      rescue => e
        Rails.logger.error "AI Image Error: #{e.message}"
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def screenshot_to_code
        unless AiConfiguration.screenshot_enabled?
          return render json: { error: "Screenshot to code is disabled" }, status: :forbidden
        end

        unless params[:screenshot].present?
          return render json: { error: "No screenshot provided" }, status: :bad_request
        end

        html = AiService.screenshot_to_code(
          image_data: params[:screenshot],
          model: params[:model],
          additional_prompt: params[:additional_prompt]
        )

        render json: { success: true, html: html }
      rescue => e
        Rails.logger.error "AI Screenshot Error: #{e.message}"
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def models
        render json: {
          text: AiModels.text_models,
          image: AiModels.image_models,
          vision: AiModels.vision_models,
          default_text: Setting.ai_default_text_model,
          default_image: Setting.ai_default_image_model,
          default_vision: Setting.ai_default_vision_model
        }
      end

      def status
        render json: {
          configured: AiConfiguration.configured?,
          providers: AiConfiguration.configured_providers,
          text_enabled: AiConfiguration.text_enabled?,
          image_enabled: AiConfiguration.image_enabled?,
          screenshot_enabled: AiConfiguration.screenshot_enabled?
        }
      end

      private

      def ensure_ai_configured
        unless AiConfiguration.configured?
          render json: {
            error: "AI not configured. Add API keys in Settings > AI."
          }, status: :service_unavailable
        end
      end

      def build_context
        context = ""

        if params[:mode] == "element" && params[:current_html].present?
          context = "You are modifying an existing element. Here is the current HTML:\n```html\n#{params[:current_html]}\n```\n\nModify or enhance this element based on the user's request."
        elsif params[:mode] == "page"
          context = "Generate a complete page section or component that can be inserted into a page."
        end

        context
      end

      def write_sse_event(event, data)
        response.stream.write("event: #{event}\ndata: #{data.to_json}\n\n")
      end
    end
  end
end
