module ActiveCanvas
  class CollectionItem < ApplicationRecord
    belongs_to :collection
    has_many :versions, class_name: "ActiveCanvas::CollectionItemVersion", dependent: :destroy

    attribute :data, default: {}
    attribute :draft_data, default: {}

    validates :status, inclusion: { in: %w[draft published] }

    scope :published, -> { where(status: "published") }
    scope :draft, -> { where(status: "draft") }

    # Coerce raw form input (string keys = field ids) into draft_data using the
    # collection schema. Unknown fields are dropped; each value is type-coerced.
    def assign_fields(raw)
      self.draft_data = draft_data.merge(schema.coerce_all_for_storage(raw))
    end

    def pending_changes?
      ids = schema.field_ids
      draft_data.slice(*ids) != data.slice(*ids)
    end

    # What the admin grid shows: the public snapshot for published items,
    # the draft for everything else.
    def effective_data
      status == "published" ? data : draft_data
    end

    # Copies the draft into the public snapshot and records a version. The row
    # lock serializes concurrent publishes so version numbers stay monotonic.
    # Call on a saved record: with_lock reloads it. Returns false with an error
    # when a required field is blank. The draft is normalized to the same
    # snapshot, so pending_changes? is false right after publishing.
    def publish
      published = false
      with_lock do
        snapshot = schema.coerce_all_for_storage(draft_data)
        missing = schema.missing_required_labels(snapshot)
        if missing.any?
          errors.add(:base, "Fill in the required fields before publishing: #{missing.join(", ")}")
        else
          update!(data: snapshot, draft_data: snapshot, status: "published", published_at: Time.current)
          versions.create!(data: data, changed_by: Current.editor)
          published = true
        end
      end
      published
    end

    def publish!
      publish || raise(ActiveRecord::RecordInvalid.new(self))
    end

    def unpublish!
      with_lock { update!(status: "draft") }
    end

    private

    def schema
      CollectionSchema.new(collection.fields)
    end
  end
end
