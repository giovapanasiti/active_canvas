require "date"

module ActiveCanvas
  # Pure value object over a Collection's `fields` array. Coerces raw input for
  # JSON storage and stored values for Liquid. The single source of truth for
  # per-type conversion, shared by CollectionItem (write) and CollectionSource (read).
  class CollectionSchema
    VALID_FIELD_TYPES = %w[text textarea rich_text number boolean date select media].freeze

    def self.generate_field_id(label, taken)
      base = label.to_s.parameterize(separator: "_").tr("-", "_").squeeze("_").gsub(/\A_+|_+\z/, "").presence || "field"
      base = "f_#{base}" unless base.match?(/\A[a-z]/)
      candidate = base
      counter = 1
      while taken.include?(candidate)
        counter += 1
        candidate = "#{base}_#{counter}"
      end
      candidate
    end

    def initialize(fields)
      @fields = (fields || []).map { |f| f.transform_keys(&:to_s) }
    end

    def field_ids
      @fields.map { |f| f["id"] }
    end

    def field(id)
      @fields.find { |f| f["id"] == id.to_s }
    end

    def coerce_for_storage(field_id, value)
      spec = field(field_id)
      return nil unless spec

      case spec["type"]
      when "number"    then coerce_number(value)
      when "boolean"   then ActiveModel::Type::Boolean.new.cast(value) || false
      when "date"      then coerce_date(value)
      when "rich_text" then ContentSanitizer.sanitize_html(value.to_s)
      when "media"     then value.presence && value.to_i
      when "select"    then Array(spec["options"]).include?(value.to_s) ? value.to_s : nil
      else value.to_s.presence
      end
    end

    # Coerces every schema field present in `raw`; unknown keys are dropped.
    # Used both for form input and to rebuild the published snapshot, so data
    # written around assign_fields (console, seeds) is still sanitized.
    # A select value whose option was removed becomes nil, so a required
    # select can stop a previously valid draft from publishing until it is
    # edited.
    def coerce_all_for_storage(raw)
      raw = (raw || {}).transform_keys(&:to_s)
      field_ids.each_with_object({}) do |id, acc|
        acc[id] = coerce_for_storage(id, raw[id]) if raw.key?(id)
      end
    end

    # Labels of required fields with no value. Booleans are never "missing":
    # false is a value.
    def missing_required_labels(data)
      data = (data || {}).transform_keys(&:to_s)
      @fields.select { |f| f["required"] && f["type"] != "boolean" && data[f["id"]].blank? }.map { |f| f["label"] }
    end

    # Values handed to Liquid. Text is HTML-escaped here; rich_text was
    # sanitized on write and is marked html_safe so the resolver leaves it alone.
    def coerce_for_liquid(field_id, value, media_urls: nil)
      spec = field(field_id)
      return nil unless spec

      case spec["type"]
      when "number", "boolean" then value
      when "date"      then (Date.iso8601(value.to_s) rescue nil)
      when "rich_text" then value.to_s.html_safe
      when "media"     then ERB::Util.html_escape(resolve_media_url(value, media_urls))
      else ERB::Util.html_escape(value.to_s)
      end
    end

    private

    def coerce_number(value)
      return value if value.is_a?(Numeric)
      return nil if value.to_s.strip.empty?
      Integer(value)
    rescue ArgumentError, TypeError
      begin
        Float(value)
      rescue ArgumentError, TypeError
        nil
      end
    end

    def coerce_date(value)
      return nil if value.to_s.strip.empty?
      Date.parse(value.to_s).iso8601
    rescue ArgumentError, TypeError
      nil
    end

    def resolve_media_url(value, media_urls)
      return media_urls[value].to_s if media_urls
      ActiveCanvas::Media.find_by(id: value)&.url.to_s
    end
  end
end
