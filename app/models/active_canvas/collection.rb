module ActiveCanvas
  class Collection < ApplicationRecord
    RESERVED_SLUGS = %w[_literal].freeze
    # Keys CollectionSource puts on every row; a field may not shadow them.
    RESERVED_FIELD_IDS = %w[id slug published_at].freeze
    FIELD_ID_FORMAT = /\A[a-z][a-z0-9_]*\z/

    has_many :items, class_name: "ActiveCanvas::CollectionItem", dependent: :destroy

    attribute :fields, default: []

    before_validation :normalize_slug
    before_validation :assign_missing_field_ids

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: true
    validate :slug_not_reserved
    validate :fields_well_formed

    def item_name
      ActiveCanvas::DataSources.item_name(slug)
    end

    # The params an editor can set on a binding to this collection, in the
    # same shape as DataSources::Source#param_schema plus field labels.
    def param_schema
      ids = fields.map { |f| f["id"] }
      labels = fields.each_with_object({}) { |f, acc| acc[f["id"]] = f["label"] }
      {
        limit:        { type: :integer, default: CollectionSource::DEFAULT_LIMIT, range: [ 1, CollectionSource::MAX_LIMIT ], allowed: nil },
        sort_field:   { type: :string, default: nil, range: nil, allowed: ids, labels: labels },
        sort_dir:     { type: :string, default: "desc", range: nil, allowed: %w[asc desc] },
        filter_field: { type: :string, default: nil, range: nil, allowed: ids, labels: labels },
        filter_value: { type: :string, default: nil, range: nil, allowed: nil }
      }
    end

    # The field builder posts its rows as one JSON string.
    def fields_json=(json)
      @fields_unreadable = false
      self.fields = json.blank? ? [] : JSON.parse(json)
    rescue JSON::ParserError, TypeError
      @fields_unreadable = true
    end

    def fields_json
      (fields.is_a?(Array) ? fields : []).to_json
    end

    private

    def normalize_slug
      self.slug = (slug.presence || name).to_s.parameterize
    end

    def assign_missing_field_ids
      return unless fields_readable?

      taken = RESERVED_FIELD_IDS.dup
      self.fields = fields.map do |field|
        field = field.transform_keys(&:to_s)
        id = field["id"].presence || CollectionSchema.generate_field_id(field["label"], taken)
        taken << id
        field.merge("id" => id)
      end
    end

    def slug_not_reserved
      return if slug.blank?

      if RESERVED_SLUGS.include?(slug) || ActiveCanvas::DataSources.registered_names.map(&:to_s).include?(slug)
        errors.add(:slug, "is reserved by a registered data source")
      end
    end

    def fields_readable?
      fields.is_a?(Array) && fields.all?(Hash)
    end

    def fields_well_formed
      return errors.add(:fields, "could not be read") if @fields_unreadable || !fields_readable?

      seen = []
      fields.each do |field|
        errors.add(:fields, "must each have a label") if field["label"].blank?
        errors.add(:fields, "have an unknown type: #{field["type"]}") unless CollectionSchema::VALID_FIELD_TYPES.include?(field["type"])
        errors.add(:fields, "have an invalid id: #{field["id"]} (ids are lower_snake_case; remove the field and add it again)") unless field["id"].to_s.match?(FIELD_ID_FORMAT)
        errors.add(:fields, "use a reserved id: #{field["id"]}") if RESERVED_FIELD_IDS.include?(field["id"])
        errors.add(:fields, "have duplicate ids: #{field["id"]}") if seen.include?(field["id"])
        seen << field["id"]
      end
    end
  end
end
