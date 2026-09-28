module ActiveCanvas
  class SitemapController < ApplicationController
    # Per the sitemaps.org protocol, a single sitemap file may list at most
    # 50,000 URLs. Above that a sitemap index is required (not yet implemented).
    URL_LIMIT = 50_000

    def show
      return head :not_found unless ActiveCanvas::Seo.sitemap_enabled?

      @pages = ActiveCanvas::Seo.sitemap_pages
      if @pages.size > URL_LIMIT
        Rails.logger.warn(
          "[ActiveCanvas] sitemap has #{@pages.size} URLs, exceeding the " \
          "#{URL_LIMIT} single-file limit; sitemap index is not yet implemented."
        )
      end

      render formats: [ :xml ]
    end
  end
end
