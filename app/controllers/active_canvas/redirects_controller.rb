module ActiveCanvas
  class RedirectsController < ApplicationController
    def show
      page = PageRedirect.find_by(from_slug: params[:slug])&.page
      raise ActionController::RoutingError, "Not Found" unless page&.published? && page.slug.present?

      redirect_to public_page_path(page.slug), status: :moved_permanently
    end
  end
end
