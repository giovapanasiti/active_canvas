module ActiveCanvas
  class RobotsController < ApplicationController
    def show
      sitemap_url = ActiveCanvas::Seo.sitemap_enabled? ? sitemap_url_string : nil
      render plain: ActiveCanvas::Seo.robots_txt(sitemap_url: sitemap_url),
             content_type: "text/plain"
    end

    private

    # Build the sitemap URL relative to wherever the engine is mounted, so it
    # works whether the engine lives at "/" or "/canvas". robots.txt is served
    # at "<mount>/robots.txt"; swap the last segment for "sitemap.xml".
    def sitemap_url_string
      request.base_url + request.path.sub(/robots\.txt\z/, "sitemap.xml")
    end
  end
end
