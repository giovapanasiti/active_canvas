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
