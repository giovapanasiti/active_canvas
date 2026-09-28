module ActiveCanvas
  # Resolves a Collection into Liquid-safe row hashes for a dynamic-data loop.
  # Loads published items, applies equality filter / sort / limit, and maps each
  # item's stored data through the collection schema's Liquid coercion.
  class CollectionSource
    DEFAULT_LIMIT = 100
    MAX_LIMIT = 500

    def initialize(collection)
      @collection = collection
      @schema = CollectionSchema.new(collection.fields)
    end

    def resolve(params = {})
      params = (params || {}).transform_keys(&:to_s)
      items = @collection.items.published.to_a
      items = filter(items, params)
      items = sort(items, params)
      items = items.first(clamped_limit(params))
      media_urls = preload_media_urls(items) { |item| item.data }
      items.map { |item| base_row(item, item.data, media_urls) }
    end

    # The row shape template pages, the draft preview and the editor's
    # implicit context share (Part 4 "Item row"): the same fields `resolve`
    # exposes, plus `url` (the item's public show-page URL) and `seo`
    # (`{ title, description, image_url }`, already resolved through the
    # `_seo` -> field -> slug fallback chain). `data:` selects the published
    # snapshot or the draft, so an unpublished item can still be previewed.
    def row_for(item, data: :published)
      rows_for([ item ], data: data).first
    end

    def rows_for(items, data: :published)
      items = Array(items)
      source_data = items.index_with { |item| data == :draft ? item.draft_data : item.data }
      media_urls = preload_media_urls(items) { |item| source_data[item] }
      seo_media_urls = preload_seo_media_urls(items, source_data)

      items.map do |item|
        row = base_row(item, source_data[item], media_urls)
        # A collection without public pages may still own a `url`/`seo`
        # field (Collection::PAGES_RESERVED_FIELD_IDS); its value wins.
        row["url"] = item_url(item) unless @schema.field("url")
        row["seo"] = resolve_seo(item, source_data[item], media_urls, seo_media_urls) unless @schema.field("seo")
        row
      end
    end

    # The collection index page's public URL, engine-mount aware. Shared with
    # CollectionPageContext for the `collection.url` implicit assign.
    def index_url
      url_helpers.public_collection_index_path(@collection.slug)
    end

    # Raw (unescaped) title/description/image URL for an item's public head
    # tags (Task 4's CollectionPagesController show action and the admin
    # draft preview), same fallback chain `row_for`'s `seo` key uses but not
    # HTML-escaped -- the ERB head partial escapes on output itself, and
    # escaping twice would double-encode a value like "<script>".
    def head_seo(item, data: :published)
      item_data = data == :draft ? item.draft_data : item.data
      media_urls = preload_media_urls([ item ]) { item_data }
      seo_media_urls = preload_seo_media_urls([ item ], { item => item_data })
      raw_seo(item, item_data, media_urls, seo_media_urls)
    end

    private

    def filter(items, params)
      field = params["filter_field"]
      value = params["filter_value"]
      return items unless field.present? && value.present? && @schema.field(field)

      items.select { |item| item.data[field].to_s == value.to_s }
    end

    def sort(items, params)
      spec = @schema.field(params["sort_field"]) if params["sort_field"].present?
      return items.sort_by { |item| [ item.published_at || Time.at(0), item.id ] }.reverse unless spec

      sortable, unsortable = items.partition { |item| sortable?(spec, item.data[spec["id"]]) }
      sorted = sortable.sort_by { |item| [ sort_key(spec, item.data[spec["id"]]), item.id ] }
      sorted.reverse! unless params["sort_dir"] == "asc"
      sorted + unsortable.sort_by(&:id) # nils and unreadable values go last both ways
    end

    def sortable?(spec, value)
      case spec["type"]
      when "number"  then value.is_a?(Numeric)
      when "boolean" then !value.nil?
      else value.present?
      end
    end

    def sort_key(spec, value)
      case spec["type"]
      when "number"  then value
      when "boolean" then value ? 1 : 0
      else value.to_s.downcase # dates are ISO-8601, so lexical order is chronological
      end
    end

    def clamped_limit(params)
      limit = Integer(params["limit"], exception: false) if params["limit"].present?
      limit = DEFAULT_LIMIT if limit.nil? || limit <= 0
      [ limit, MAX_LIMIT ].min
    end

    def preload_media_urls(items)
      media_ids = @schema.field_ids.select { |id| @schema.field(id)["type"] == "media" }
      return {} if media_ids.empty?

      ids = items.flat_map { |item| media_ids.map { |fid| yield(item)[fid] } }.compact.uniq
      ActiveCanvas::Media.where(id: ids).index_by(&:id).transform_values(&:url)
    end

    def preload_seo_media_urls(items, source_data)
      ids = items.filter_map { |item| seo_data_for(source_data[item])["og_image_media_id"] }.uniq
      return {} if ids.empty?

      ActiveCanvas::Media.where(id: ids).index_by(&:id).transform_values(&:url)
    end

    def base_row(item, data, media_urls)
      base = { "id" => item.id, "slug" => item.slug, "published_at" => item.published_at }
      @schema.field_ids.each_with_object(base) do |field_id, acc|
        acc[field_id] = @schema.coerce_for_liquid(field_id, (data || {})[field_id], media_urls: media_urls)
      end
    end

    def seo_data_for(data)
      seo = data.is_a?(Hash) ? data["_seo"] : nil
      seo.is_a?(Hash) ? seo : {}
    end

    # `_seo.meta_title` -> the collection's title field (plain text) -> the
    # item's own slug, which always exists. Description stops one step
    # earlier (no slug fallback): `_seo.meta_description` -> the description
    # field, plain text and truncated to 160 chars. Image: `_seo`'s media id
    # -> the image field's media id. This is the per-item fallback chain
    # only (Part 4 "SEO & sitemap"); the site-wide default and
    # `Seo.compose_title` are applied by the page/head-tag layer, not here.
    def raw_seo(item, data, media_urls, seo_media_urls)
      seo = seo_data_for(data)

      title = seo["meta_title"].to_s.strip.presence ||
        field_plain_text(@collection.title_field, data).presence ||
        item.slug.to_s

      description = seo["meta_description"].to_s.strip.presence ||
        field_plain_text(@collection.description_field, data)&.truncate(160)

      image_url = seo_media_urls[seo["og_image_media_id"]] || image_field_url(data, media_urls)

      { title: title, description: description, image_url: image_url }
    end

    # The escaped shape `row_for`'s `seo` key exposes to Liquid.
    def resolve_seo(item, data, media_urls, seo_media_urls)
      raw = raw_seo(item, data, media_urls, seo_media_urls)

      {
        "title" => escape(raw[:title]),
        "description" => escape(raw[:description].to_s),
        "image_url" => raw[:image_url].present? ? escape(raw[:image_url]) : nil
      }
    end

    def image_field_url(data, media_urls)
      field_id = @collection.image_field
      return nil if field_id.blank?

      media_urls[(data || {})[field_id]]
    end

    def field_plain_text(field_id, data)
      return nil if field_id.blank?

      spec = @schema.field(field_id)
      return nil unless spec

      value = (data || {})[field_id]
      return nil if value.blank?

      spec["type"] == "rich_text" ? ActionText::Content.new(value.to_s).to_plain_text.squish : value.to_s
    end

    # A collection without `has_pages` doesn't enforce item slugs (Part 3), so
    # an item can be slugless here even though only a `has_pages` collection
    # is ever routed publicly. The named route requires a non-blank segment;
    # degrade to a path under the index rather than raise.
    def item_url(item)
      return escape("#{index_url}/") if item.slug.blank?

      escape(url_helpers.public_collection_item_path(@collection.slug, item.slug))
    end

    def url_helpers
      ActiveCanvas::Engine.routes.url_helpers
    end

    def escape(value)
      ERB::Util.html_escape(value.to_s)
    end
  end
end
