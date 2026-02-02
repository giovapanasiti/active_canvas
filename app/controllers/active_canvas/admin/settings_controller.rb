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
    end
  end
end
