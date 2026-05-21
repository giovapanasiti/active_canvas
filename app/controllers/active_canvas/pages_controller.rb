module ActiveCanvas
  class PagesController < ApplicationController
    after_action :set_dynamic_cache_headers, only: %i[show home]

    def home
      @page = Setting.homepage

      if @page
        render :show
      else
        render :no_homepage
      end
    end

    def show
      @page = Page.published.find_by(slug: params[:slug])
      raise ActionController::RoutingError, "Not Found" unless @page
    end

    private

    def set_dynamic_cache_headers
      return unless @page.respond_to?(:template_enabled?) && @page&.template_enabled?
      response.headers["Cache-Control"] = "no-store"
    end
  end
end
