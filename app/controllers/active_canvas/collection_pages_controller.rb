module ActiveCanvas
  # Renders a `has_pages` collection's public index/show pages (Part 4
  # "Public routing") through its `index`/`show` template page, the same way
  # PagesController#show renders a regular page: the implicit assigns come
  # from CollectionPageContext, and both actions are always dynamic, so the
  # response is never cached (like any other template-enabled page).
  class CollectionPagesController < ApplicationController
    after_action :set_dynamic_cache_headers

    before_action :set_collection

    def index
      page_number = parse_page_param
      raise ActionController::RoutingError, "Not Found" unless page_number

      begin
        @context = ActiveCanvas::CollectionPageContext.index(@collection, page: page_number)
      rescue ActiveCanvas::CollectionPageContext::PageOutOfRange
        raise ActionController::RoutingError, "Not Found"
      end

      @page = template_page("index")
    end

    def show
      @item = @collection.items.published.find_by(slug: params[:item_slug])
      raise ActionController::RoutingError, "Not Found" unless @item

      @context = ActiveCanvas::CollectionPageContext.show(@item)
      @head_seo = ActiveCanvas::CollectionSource.new(@collection).head_seo(@item)
      @page = template_page("show")
    end

    private

    def set_collection
      @collection = ActiveCanvas::Collection.with_pages.find_by(slug: params[:collection_slug])
      raise ActionController::RoutingError, "Not Found" unless @collection
    end

    def template_page(role)
      @collection.template_pages.find_by(collection_role: role) ||
        (raise ActionController::RoutingError, "Not Found")
    end

    # nil (blank) means page 1; "0", a negative number, anything non-numeric
    # ("abc") or a non-string param (?page[]=1, ?page[x]=1) is
    # out of range; CollectionPageContext#index catches anything above
    # total_pages. Both cases 404 (Part 4 "Public routing").
    def parse_page_param
      raw = params[:page]
      return 1 if raw.blank?
      return nil unless raw.is_a?(String) && raw.match?(/\A[1-9]\d*\z/)

      raw.to_i
    end

    def set_dynamic_cache_headers
      response.headers["Cache-Control"] = "no-store"
    end
  end
end
