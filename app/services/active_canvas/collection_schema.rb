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
      when "rich_text" then coerce_rich_text_for_storage(value)
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

    # Coerces the reserved "_seo" data key: strings are trimmed (blank ones
    # dropped), the media id must reference an existing Media or is dropped.
    # Unlike coerce_all_for_storage this isn't keyed by a schema field, since
    # "_seo" lives outside the fields namespace (Collection::RESERVED_FIELD_IDS).
    def coerce_seo(raw)
      raw = (raw || {}).transform_keys(&:to_s)
      {
        "meta_title" => raw["meta_title"].to_s.strip.presence,
        "meta_description" => raw["meta_description"].to_s.strip.presence,
        "og_image_media_id" => coerce_seo_media_id(raw["og_image_media_id"])
      }.compact
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
      when "rich_text" then render_rich_text_for_liquid(value)
      when "media"     then ERB::Util.html_escape(resolve_media_url(value, media_urls))
      else ERB::Util.html_escape(value.to_s)
      end
    end

    private

    # `data-ac-media-id` is our own stable-media-reference attribute (see
    # ContentRenderer / MediaRefBackfill). It is not part of Action Text's
    # default safe list, so without this it would be stripped on every save,
    # breaking the importer's plain-string remap of rich_text media refs on
    # export/import (see importer_media_test.rb). This only affects storage:
    # coerce_for_liquid's sanitizer is Action Text's own (global) allowed-
    # attributes list, which does NOT include this attribute, so it is still
    # stripped when a rich_text field is rendered for Liquid output -- there
    # is no resolution step (unlike page content's ContentRenderer) that turns
    # a rich_text data-ac-media-id reference into a real URL before display.
    RICH_TEXT_EXTRA_ATTRIBUTES = %w[data-ac-media-id].freeze

    # Storage: sanitize with Action Text's own safe list (tags/attributes it
    # ships with, extended by Lexxy for video/audio/table/etc., plus
    # action-text-attachment) rather than ContentSanitizer, then canonicalize
    # through ActionText::Content so attachment markup matches what Action
    # Text itself would produce.
    def coerce_rich_text_for_storage(value)
      html = value.to_s
      return "" if html.blank?

      sanitized = ActionText::ContentHelper.sanitizer.sanitize(
        html,
        tags: rich_text_allowed_tags,
        attributes: rich_text_allowed_attributes,
        scrubber: ActionText::ContentHelper.scrubber
      )
      ActionText::Content.new(sanitized).to_html
    end

    # Liquid: render through Action Text so attachments (images, etc.) become
    # their full markup, not just the bare <action-text-attachment> tag.
    # Always rendered with the host app's routes (Active Storage URLs), on the
    # current request's host when one is on record -- see
    # RequestScopedRenderer. Works outside a request too.
    def render_rich_text_for_liquid(value)
      html = value.to_s
      return "".html_safe if html.blank?

      ActiveCanvas::RequestScopedRenderer.with_rich_text_renderer do
        ActionText::Content.new(html).to_rendered_html_with_layout.html_safe
      end
    end

    def rich_text_content_helper
      @rich_text_content_helper ||= Class.new { include ActionText::ContentHelper }.new
    end

    def rich_text_allowed_tags
      rich_text_content_helper.sanitizer_allowed_tags
    end

    def rich_text_allowed_attributes
      rich_text_content_helper.sanitizer_allowed_attributes + RICH_TEXT_EXTRA_ATTRIBUTES
    end

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

    def coerce_seo_media_id(value)
      id = value.presence && value.to_i
      return nil unless id
      ActiveCanvas::Media.exists?(id: id) ? id : nil
    end

    def resolve_media_url(value, media_urls)
      return media_urls[value].to_s if media_urls
      ActiveCanvas::Media.find_by(id: value)&.url.to_s
    end
  end
end
