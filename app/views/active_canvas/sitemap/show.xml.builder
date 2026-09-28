xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  @pages.each do |page|
    loc = ActiveCanvas::Seo.homepage?(page) ? root_url : public_page_url(page.slug)
    xml.url do
      xml.loc loc
      xml.lastmod page.updated_at.utc.xmlschema
    end
  end

  @collections.each do |collection|
    xml.url do
      xml.loc public_collection_index_url(collection.slug)
    end
    collection.items.published.where.not(slug: [ nil, "" ]).each do |item|
      xml.url do
        xml.loc public_collection_item_url(collection.slug, item.slug)
        xml.lastmod item.updated_at.utc.xmlschema
      end
    end
  end
end
