module ActiveCanvas
  module Admin
    class SettingsController < ApplicationController
      def show
        @active_tab = params[:tab] || "general"
        @homepage_page_id = Setting.homepage_page_id
        @css_framework = Setting.css_framework
        @global_css = Setting.global_css
        @global_js = Setting.global_js
        @custom_head_html = Setting.custom_head_html
        @pages = Page.published.order(:title)

        # Tailwind settings
        @tailwind_config = Setting.tailwind_config_js
        @tailwind_available = ActiveCanvas::TailwindCompiler.available?
        @tailwind_compiled_mode = Setting.tailwind_compiled_mode?

        # AI settings - use masked values for display
        @ai_openai_key = Setting.masked_api_key("ai_openai_api_key")
        @ai_anthropic_key = Setting.masked_api_key("ai_anthropic_api_key")
        @ai_openrouter_key = Setting.masked_api_key("ai_openrouter_api_key")
        @ai_openai_configured = Setting.api_key_configured?("ai_openai_api_key")
        @ai_anthropic_configured = Setting.api_key_configured?("ai_anthropic_api_key")
        @ai_openrouter_configured = Setting.api_key_configured?("ai_openrouter_api_key")
        @ai_default_text_model = Setting.ai_default_text_model
        @ai_default_image_model = Setting.ai_default_image_model
        @ai_text_enabled = Setting.ai_text_enabled?
        @ai_image_enabled = Setting.ai_image_enabled?
        @ai_screenshot_enabled = Setting.ai_screenshot_enabled?

        # Model sync info
        @ai_models_synced = AiModels.models_synced?
        @ai_models_last_synced = AiModels.last_synced_at
        @ai_models_count = AiModel.count if @ai_models_synced
        @ai_default_vision_model = Setting.ai_default_vision_model
        @ai_connection_mode = Setting.ai_connection_mode
        @ai_text_models = AiModels.all_text_models
        @ai_image_models = AiModels.all_image_models
        @ai_vision_models = AiModels.all_vision_models

        # Models tab - models from configured providers only
        if @active_tab == "models"
          configured_providers = AiConfiguration.configured_providers
          @all_models_by_provider = AiModel
            .where(provider: configured_providers)
            .order(:provider, :model_type, :name)
            .group_by(&:provider)
        end

        @api_tokens = ApiToken.order(created_at: :desc) if @active_tab == "api_tokens"

        if @active_tab == "seo"
          @seo_site_name = Setting.seo_site_name
          @seo_title_template = Setting.seo_title_template
          @seo_default_meta_description = Setting.seo_default_meta_description
          @seo_favicon_media_id = Setting.seo_favicon_media_id
          @seo_default_og_image_media_id = Setting.seo_default_og_image_media_id
          @seo_google_site_verification = Setting.seo_google_site_verification
          @seo_bing_site_verification = Setting.seo_bing_site_verification
          @seo_robots_txt = Setting.seo_robots_txt
          @seo_sitemap_enabled = Setting.seo_sitemap_enabled?
          @seo_media_images = ActiveCanvas::Media.images.recent
        end
      end

      def update
        Setting.homepage_page_id = params[:homepage_page_id]

        redirect_to admin_settings_path, notice: "Settings saved successfully."
      end

      def update_seo
        ActiveCanvas::SeoSettingsUpdate.call(params)

        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "seo"), notice: "SEO settings saved." }
          format.json { render json: { success: true, message: "SEO settings saved." } }
        end
      rescue ActiveRecord::RecordNotFound
        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "seo"), alert: "Media not found." }
          format.json { render json: { success: false, error: "Media not found" }, status: :unprocessable_entity }
        end
      end

      def update_global_css
        Setting.global_css = params[:global_css]

        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "styles"), notice: "Global CSS saved." }
          format.json { render json: { success: true, message: "Global CSS saved." } }
        end
      end

      def update_global_js
        Setting.global_js = params[:global_js]

        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "scripts"), notice: "Global JavaScript saved." }
          format.json { render json: { success: true, message: "Global JavaScript saved." } }
        end
      end

      def update_custom_head
        Setting.custom_head_html = params[:custom_head_html]

        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "scripts"), notice: "Custom head HTML saved." }
          format.json { render json: { success: true, message: "Custom head HTML saved." } }
        end
      end

      def update_ai
        ActiveCanvas::AiSettingsUpdate.call(params)

        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "ai"), notice: "AI settings saved." }
          format.json { render json: { success: true, message: "AI settings saved." } }
        end
      end

      def sync_ai_models
        unless AiConfiguration.configured?
          respond_to do |format|
            format.html { redirect_to admin_settings_path(tab: "ai"), alert: "Please configure at least one API key first." }
            format.json { render json: { success: false, error: "Not configured" }, status: :unprocessable_entity }
          end
          return
        end

        begin
          count = AiModels.refresh!

          respond_to do |format|
            format.html { redirect_to admin_settings_path(tab: "ai"), notice: "Synced #{count} models from providers." }
            format.json { render json: { success: true, count: count, message: "Synced #{count} models." } }
          end
        rescue => e
          Rails.logger.error "AI Model Sync Error: #{e.message}"
          respond_to do |format|
            format.html { redirect_to admin_settings_path(tab: "ai"), alert: "Failed to sync models: #{e.message}" }
            format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
          end
        end
      end

      def toggle_ai_model
        model = AiModel.find(params[:model_id])
        model.update!(active: !model.active)

        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "models"), notice: "#{model.display_name} #{model.active? ? 'activated' : 'deactivated'}." }
          format.json { render json: { success: true, active: model.active, model_id: model.id } }
        end
      rescue ActiveRecord::RecordNotFound
        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "models"), alert: "Model not found." }
          format.json { render json: { success: false, error: "Model not found" }, status: :not_found }
        end
      end

      def create_ai_model
        model = AiModel.create_from_params!(params)

        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "models"), notice: "Model '#{model.display_name}' added." }
          format.json { render json: { success: true, model: model.as_json_for_editor } }
        end
      rescue ActiveRecord::RecordInvalid => e
        model = e.record
        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "models"), alert: model.errors.full_messages.to_sentence }
          format.json { render json: { success: false, errors: model.errors.full_messages }, status: :unprocessable_entity }
        end
      end

      def destroy_ai_model
        model = AiModel.find(params[:model_id])
        model.destroy!

        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "models"), notice: "Model '#{model.display_name}' removed." }
          format.json { render json: { success: true } }
        end
      rescue ActiveRecord::RecordNotFound
        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "models"), alert: "Model not found." }
          format.json { render json: { success: false, error: "Model not found" }, status: :not_found }
        end
      end

      def bulk_toggle_ai_models
        action = params[:action_type]
        scope = params[:scope]
        provider = params[:provider]

        models = AiModel.all
        models = models.where(provider: provider) if provider.present?
        models = models.where(model_type: scope) if scope.present? && scope != "all"

        case action
        when "activate"
          count = models.update_all(active: true)
          message = "Activated #{count} models."
        when "deactivate"
          count = models.update_all(active: false)
          message = "Deactivated #{count} models."
        else
          message = "Invalid action."
        end

        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "models"), notice: message }
          format.json { render json: { success: true, count: count, message: message } }
        end
      end

      def update_tailwind_config
        Setting.tailwind_config = params[:tailwind_config]

        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "styles"), notice: "Tailwind configuration saved." }
          format.json { render json: { success: true, message: "Tailwind configuration saved." } }
        end
      end

      def recompile_tailwind
        result = ActiveCanvas::TailwindRecompile.call

        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "styles"), notice: "Queued #{result[:enqueued]} pages for Tailwind compilation." }
          format.json { render json: { success: true, count: result[:enqueued], message: "Queued #{result[:enqueued]} pages for compilation." } }
        end
      rescue ActiveCanvas::TailwindRecompile::Unavailable => e
        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "styles"), alert: e.message }
          format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
        end
      end
    end
  end
end
