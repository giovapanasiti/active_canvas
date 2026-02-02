module ActiveCanvas
  module Admin
    class SettingsController < ApplicationController
      def show
        @homepage_page_id = Setting.homepage_page_id
        @pages = Page.published.order(:title)
      end

      def update
        Setting.homepage_page_id = params[:homepage_page_id]

        redirect_to admin_settings_path, notice: "Settings saved successfully."
      end
    end
  end
end
