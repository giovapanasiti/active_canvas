module ActiveCanvas
  class CollectionItem < ApplicationRecord
    belongs_to :collection
    has_many :versions, class_name: "ActiveCanvas::CollectionItemVersion", dependent: :destroy

    attribute :data, default: {}
    attribute :draft_data, default: {}

    scope :published, -> { where(status: "published") }
    scope :draft, -> { where(status: "draft") }

    # Coerce raw form input (string keys = field ids) into draft_data using the
    # collection schema. Unknown fields are dropped; each value is type-coerced.
    def assign_fields(raw)
      schema = CollectionSchema.new(collection.fields)
      coerced = {}
      schema.field_ids.each do |field_id|
        next unless raw.key?(field_id)
        coerced[field_id] = schema.coerce_for_storage(field_id, raw[field_id])
      end
      self.draft_data = draft_data.merge(coerced)
    end
  end
end
