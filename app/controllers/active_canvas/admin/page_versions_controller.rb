module ActiveCanvas
  module Admin
    class PageVersionsController < ApplicationController
      before_action :set_page
      before_action :set_version

      def show
        @previous_version = @page.versions.where("version_number < ?", @version.version_number).order(version_number: :desc).first
        @next_version = @page.versions.where("version_number > ?", @version.version_number).order(version_number: :asc).first
      end

      private

      def set_page
        @page = Page.find(params[:page_id])
      end

      def set_version
        @version = @page.versions.find(params[:id])
      end
    end
  end
end
