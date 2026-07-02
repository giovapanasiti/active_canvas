module ActiveCanvas
  class Collection < ApplicationRecord
    RESERVED_SLUGS = %w[_literal].freeze

    has_many :items, class_name: "ActiveCanvas::CollectionItem", dependent: :destroy

    attribute :fields, default: []

    before_validation :normalize_slug
    before_validation :assign_missing_field_ids

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: true
    validate :slug_not_reserved

    private

    def normalize_slug
      self.slug = slug.to_s.parameterize if slug.present?
    end

    def assign_missing_field_ids
      taken = []
      self.fields = (fields || []).map do |field|
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
  end
end
