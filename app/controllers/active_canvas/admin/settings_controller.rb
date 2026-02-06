module ActiveCanvas
  module Admin
    class SettingsController < ApplicationController
      def show
        @active_tab = params[:tab] || "general"
        @homepage_page_id = Setting.homepage_page_id
        @css_framework = Setting.css_framework
        @global_css = Setting.global_css
        @global_js = Setting.global_js
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
      end

      def update
        Setting.homepage_page_id = params[:homepage_page_id]
        Setting.css_framework = params[:css_framework]

        redirect_to admin_settings_path, notice: "Settings saved successfully."
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

      def update_ai
        # API Keys - only update if a new value is provided (not empty, not masked)
        update_api_key("ai_openai_api_key", params[:ai_openai_api_key])
        update_api_key("ai_anthropic_api_key", params[:ai_anthropic_api_key])
        update_api_key("ai_openrouter_api_key", params[:ai_openrouter_api_key])

        # Default models
        Setting.ai_default_text_model = params[:ai_default_text_model] if params.key?(:ai_default_text_model)
        Setting.ai_default_image_model = params[:ai_default_image_model] if params.key?(:ai_default_image_model)
        Setting.ai_default_vision_model = params[:ai_default_vision_model] if params.key?(:ai_default_vision_model)

        # Feature toggles
        Setting.ai_text_enabled = params[:ai_text_enabled] == "1"
        Setting.ai_image_enabled = params[:ai_image_enabled] == "1"
        Setting.ai_screenshot_enabled = params[:ai_screenshot_enabled] == "1"

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

      private

      def update_api_key(key, value)
        return if value.blank?
        return if value.start_with?("****") # Masked value, don't update

        Setting.set(key, value)
      end

      public

      def recompile_tailwind
        unless ActiveCanvas::TailwindCompiler.available?
          respond_to do |format|
            format.html { redirect_to admin_settings_path(tab: "styles"), alert: "tailwindcss-ruby gem is not installed." }
            format.json { render json: { success: false, error: "tailwindcss-ruby gem is not installed." }, status: :unprocessable_entity }
          end
          return
        end

        unless Setting.css_framework == "tailwind"
          respond_to do |format|
            format.html { redirect_to admin_settings_path(tab: "styles"), alert: "Tailwind is not the selected CSS framework." }
            format.json { render json: { success: false, error: "Tailwind is not the selected CSS framework." }, status: :unprocessable_entity }
          end
          return
        end

        pages = Page.where.not(content: [ nil, "" ])
        pages.find_each do |page|
          CompileTailwindJob.perform_later(page.id)
        end

        respond_to do |format|
          format.html { redirect_to admin_settings_path(tab: "styles"), notice: "Queued #{pages.count} pages for Tailwind compilation." }
          format.json { render json: { success: true, count: pages.count, message: "Queued #{pages.count} pages for compilation." } }
        end
      end
    end
  end
end
