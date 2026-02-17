module ActiveCanvas
  class PagesController < ApplicationController
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
  end
end
