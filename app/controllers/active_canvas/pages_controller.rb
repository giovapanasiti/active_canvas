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
      @page = Page.published.regular.find_by(slug: params[:slug])
      raise ActionController::RoutingError, "Not Found" unless @page
    end

    private

    def set_dynamic_cache_headers
      response.headers["Cache-Control"] = "no-store" if @page&.template_enabled?
    end
  end
end
