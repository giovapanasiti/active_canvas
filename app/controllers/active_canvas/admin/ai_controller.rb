module ActiveCanvas
  module Admin
    class AiController < ApplicationController
      include ActionController::Live
      include ActiveCanvas::RateLimitable

      # Use null_session for JSON requests (allows CSRF token via header)
      protect_from_forgery with: :null_session, if: -> { request.format.json? }

      before_action :ensure_ai_configured, except: %i[status models]
      before_action :verify_request_origin, only: %i[chat]
      before_action :check_ai_rate_limit, only: %i[chat image screenshot_to_code]

      def chat
        unless AiConfiguration.text_enabled?
          return render json: { error: "Text generation is disabled" }, status: :forbidden
        end

        response.headers["Content-Type"] = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        response.headers["X-Accel-Buffering"] = "no"
        response.headers["Connection"] = "keep-alive"

        config = ActiveCanvas.config
        start_time = Time.current
        last_write = Time.current
        total_bytes = 0

        begin
          AiService.generate_text(
            prompt: params[:prompt],
            model: params[:model],
            context: build_context
          ) do |chunk|
            # Check stream timeout
            if Time.current - start_time > config.ai_stream_timeout
              write_sse_event("error", { error: "Stream timeout exceeded" })
              break
            end

            # Check idle timeout
            if Time.current - last_write > config.ai_stream_idle_timeout
              write_sse_event("error", { error: "Idle timeout - no data received" })
              break
            end

            # Check response size limit
            chunk_content = chunk.content.to_s
            chunk_size = chunk_content.bytesize
            total_bytes += chunk_size

            if total_bytes > config.ai_max_response_size
              write_sse_event("error", { error: "Response too large" })
              break
            end

            write_sse_event("chunk", { content: chunk_content })
            last_write = Time.current
          end

          write_sse_event("done", { total_bytes: total_bytes })
        rescue IOError => e
          # Client disconnected, this is normal
          Rails.logger.debug "AI Chat client disconnected: #{e.message}"
        rescue => e
          Rails.logger.error "AI Chat Error: #{e.class.name}: #{e.message}"
          begin
            write_sse_event("error", { error: e.message })
          rescue IOError
            # Client already disconnected
          end
        ensure
          response.stream.close rescue nil
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
        text   = AiModels.text_models
        image  = AiModels.image_models
        vision = AiModels.vision_models

        unless params[:debug]
          strip = ->(list) { list.map { |m| m.except(:input_modalities, :output_modalities, "input_modalities", "output_modalities") } }
          text   = strip.call(text)
          image  = strip.call(image)
          vision = strip.call(vision)
        end

        render json: {
          text: text,
          image: image,
          vision: vision,
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

      def check_ai_rate_limit
        check_rate_limit(namespace: "ai")
      end
    end
  end
end
