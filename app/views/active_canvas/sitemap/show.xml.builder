xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  @pages.each do |page|
    loc = ActiveCanvas::Seo.homepage?(page) ? root_url : public_page_url(page.slug)
    xml.url do
      xml.loc loc
      xml.lastmod page.updated_at.utc.xmlschema
    end
  end
end
