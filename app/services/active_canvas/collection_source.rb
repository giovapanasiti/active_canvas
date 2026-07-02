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
      media_urls = preload_media_urls(items)
      items.map { |item| row(item, media_urls) }
    end

    private

    def filter(items, params)
      field = params["filter_field"]
      value = params["filter_value"]
      return items unless field.present? && value.present? && @schema.field(field)

      items.select { |item| item.data[field].to_s == value.to_s }
    end

    def sort(items, params)
      field = params["sort_field"]
      spec = @schema.field(field) if field.present?

      if spec
        sorted = items.sort_by { |item| sort_key(spec, item.data[field]) }
        params["sort_dir"] == "asc" ? sorted : sorted.reverse
      else
        items.sort_by { |item| item.published_at || Time.at(0) }.reverse
      end
    end

    def sort_key(spec, value)
      if spec["type"] == "number"
        [ value.nil? ? 1 : 0, value || 0 ]  # numeric compare, nils last
      else
        [ value.to_s ]                       # date is ISO-8601 → lexical is correct
      end
    end

    def clamped_limit(params)
      limit = params["limit"].presence&.to_i || DEFAULT_LIMIT
      limit.clamp(1, MAX_LIMIT)
    end

    def preload_media_urls(items)
      media_ids = @schema.field_ids.select { |id| @schema.field(id)["type"] == "media" }
      return {} if media_ids.empty?

      ids = items.flat_map { |item| media_ids.map { |fid| item.data[fid] } }.compact.uniq
      ActiveCanvas::Media.where(id: ids).index_by(&:id).transform_values(&:url)
    end

    def row(item, media_urls)
      base = { "id" => item.id, "slug" => item.slug, "published_at" => item.published_at }
      @schema.field_ids.each_with_object(base) do |field_id, acc|
        acc[field_id] = @schema.coerce_for_liquid(field_id, item.data[field_id], media_urls: media_urls)
      end
    end
  end
end
