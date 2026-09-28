module ActiveCanvas
  module Admin
    class PageVersionsController < ApplicationController
      before_action :set_page
      before_action :set_version

      def show
        @previous_version = @version.previous
        @next_version = @version.next
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
