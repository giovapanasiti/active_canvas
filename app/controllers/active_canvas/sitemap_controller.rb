module ActiveCanvas
  class SitemapController < ApplicationController
    # Per the sitemaps.org protocol, a single sitemap file may list at most
    # 50,000 URLs. Above that a sitemap index is required (not yet implemented).
    URL_LIMIT = 50_000

    def show
      return head :not_found unless ActiveCanvas::Seo.sitemap_enabled?

      @pages = ActiveCanvas::Seo.sitemap_pages
      @collections = ActiveCanvas::Seo.sitemap_collections
      url_count = sitemap_url_count
      if url_count > URL_LIMIT
        Rails.logger.warn(
          "[ActiveCanvas] sitemap has #{url_count} URLs, exceeding the " \
          "#{URL_LIMIT} single-file limit; sitemap index is not yet implemented."
        )
      end

      render formats: [ :xml ]
    end

    private

    # Pages, plus each collection's index URL and its routable (published,
    # slugged) item URLs -- the same set the view lists.
    def sitemap_url_count
      item_count = ActiveCanvas::CollectionItem.published
        .where(collection_id: @collections.map(&:id))
        .where.not(slug: [ nil, "" ]).count
      @pages.size + @collections.size + item_count
    end
  end
end
