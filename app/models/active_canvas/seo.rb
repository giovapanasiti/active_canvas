module ActiveCanvas
  # Stateless facade for site-wide SEO. Reads raw values from Setting and
  # computes derived data (composed titles, media urls, robots.txt body,
  # sitemap page set). Controllers and views should use this, not Setting.
  module Seo
    module_function

    def site_name
      Setting.seo_site_name
    end

    # Applies the configured title template, substituting %{title} and
    # %{site_name}. Collapses gracefully when either side is blank.
    def compose_title(page_title)
      title = page_title.to_s.strip
      name  = site_name.to_s.strip

      return name  if title.blank?
      return title if name.blank?

      Setting.seo_title_template.to_s.gsub(/%\{(title|site_name)\}/) do
        Regexp.last_match(1) == "title" ? title : name
      end
    end

    def favicon_url
      media_url(Setting.seo_favicon_media_id)
    end

    def favicon_content_type
      find_media(Setting.seo_favicon_media_id)&.content_type
    end

    def default_og_image_url
      media_url(Setting.seo_default_og_image_media_id)
    end

    def default_meta_description
      Setting.seo_default_meta_description
    end

    def google_site_verification
      Setting.seo_google_site_verification
    end

    def bing_site_verification
      Setting.seo_bing_site_verification
    end

    def sitemap_enabled?
      Setting.seo_sitemap_enabled?
    end

    # Published pages eligible for the sitemap: excludes any page whose
    # meta_robots contains "noindex" (case-insensitive).
    def sitemap_pages
      Page.published.regular.reject { |page| noindex?(page) }
    end

    # `has_pages` collections for the sitemap (Part 4 "SEO & sitemap"): each
    # contributes its index URL plus every published item's show URL, with
    # `lastmod` from the item's `updated_at`. Built in the view (collection
    # and item public URLs are named routes, not string-built here) via
    # `Collection#items.published`.
    def sitemap_collections
      Collection.with_pages
    end

    def homepage?(page)
      id = Setting.homepage_page_id
      id.present? && id.positive? && page.id == id
    end

    # sitemap_url is the fully-qualified /sitemap.xml URL, computed by the
    # caller (it needs the request host). Returns the custom robots body if
    # one is set, otherwise a generated default.
    def robots_txt(sitemap_url: nil)
      custom = Setting.seo_robots_txt
      return custom if custom.present?

      lines = [ "User-agent: *", "Allow: /" ]
      lines += [ "", "Sitemap: #{sitemap_url}" ] if sitemap_url.present? && sitemap_enabled?
      lines.join("\n") + "\n"
    end

    # --- helpers (also private instance methods via module_function) ---

    def noindex?(page)
      page.respond_to?(:meta_robots) && page.meta_robots.to_s.downcase.include?("noindex")
    end

    def find_media(id)
      return nil if id.blank?

      Media.find_by(id: id)
    end

    def media_url(id)
      find_media(id)&.url
    end
  end
end
