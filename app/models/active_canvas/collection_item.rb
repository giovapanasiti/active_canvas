module ActiveCanvas
  class CollectionItem < ApplicationRecord
    belongs_to :collection
    has_many :versions, class_name: "ActiveCanvas::CollectionItemVersion", dependent: :destroy

    attribute :data, default: {}
    attribute :draft_data, default: {}

    validates :status, inclusion: { in: %w[draft published] }
    validates :slug, presence: true, if: -> { collection&.has_pages? }
    validates :slug, uniqueness: { scope: :collection_id }, allow_nil: true

    before_validation :normalize_slug
    before_validation :generate_slug_from_title, on: :create, if: -> { collection&.has_pages? }

    scope :published, -> { where(status: "published") }
    scope :draft, -> { where(status: "draft") }

    # Generates a unique-within-the-collection slug from `base` (typically the
    # title field's raw value). Falls back to "item-<n>" when base is blank,
    # then de-duplicates with "-2", "-3", ... against the collection's other items.
    def self.generate_slug(collection, base)
      base = base.presence&.to_s&.parameterize
      base = base.presence || "item-#{collection.items.count + 1}"

      existing = collection.items.where.not(slug: nil).pluck(:slug).to_set
      candidate = base
      counter = 1
      while existing.include?(candidate)
        counter += 1
        candidate = "#{base}-#{counter}"
      end
      candidate
    end

    # Coerce raw form input (string keys = field ids) into draft_data using the
    # collection schema. Unknown fields are dropped; each value is type-coerced.
    # The reserved "_seo" key (Part 3) lives outside the fields namespace, so it
    # is coerced separately and merged in alongside the schema fields.
    def assign_fields(raw)
      raw = (raw || {}).transform_keys(&:to_s)
      merged = draft_data.merge(schema.coerce_all_for_storage(raw))
      merged = merged.merge("_seo" => schema.coerce_seo(raw["_seo"])) if raw.key?("_seo")
      self.draft_data = merged
    end

    # { "meta_title", "meta_description", "og_image_media_id" }, read from the
    # public snapshot for published items and the draft otherwise (see
    # effective_data). Missing keys are nil rather than absent.
    def seo
      stored = effective_data["_seo"] || {}
      { "meta_title" => stored["meta_title"], "meta_description" => stored["meta_description"],
        "og_image_media_id" => stored["og_image_media_id"] }
    end

    # Field values and the reserved "_seo" key both go live on publish, so a
    # draft-only change to either is a pending change.
    def pending_changes?
      ids = schema.field_ids + [ "_seo" ]
      draft_data.slice(*ids) != data.slice(*ids)
    end

    # What the admin grid shows: the public snapshot for published items,
    # the draft for everything else.
    def effective_data
      status == "published" ? data : draft_data
    end

    # Copies the draft into the public snapshot and records a version. The row
    # lock serializes concurrent publishes so version numbers stay monotonic.
    # Call on a saved record: with_lock reloads it. Returns false with errors
    # when a required field is blank or the record is otherwise invalid (e.g.
    # a missing slug in a collection with pages) -- never raises for that. The
    # draft is normalized to the same snapshot, so pending_changes? is false
    # right after publishing.
    def publish
      published = false
      with_lock do
        snapshot = schema.coerce_all_for_storage(draft_data)
        snapshot["_seo"] = schema.coerce_seo(draft_data["_seo"]) if draft_data.key?("_seo")
        missing = schema.missing_required_labels(snapshot)
        if missing.any?
          errors.add(:base, "Fill in the required fields before publishing: #{missing.join(", ")}")
        elsif update(data: snapshot, draft_data: snapshot, status: "published", published_at: Time.current)
          versions.create!(data: data, changed_by: Current.editor)
          published = true
        else
          restore_attributes(%w[data draft_data status published_at])
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

    # Gives a slug-less item one generated from its live title (the published
    # snapshot when there is one). Used when a collection turns on public
    # pages, where every item needs a slug. Skips validations on purpose: the
    # item may be otherwise invalid (e.g. a required field added later).
    def backfill_slug!
      return if slug.present?

      update_columns(slug: self.class.generate_slug(collection, title_value_for_slug(effective_data)))
    end

    private

    def schema
      CollectionSchema.new(collection.fields)
    end

    # Blank means "no slug" (nil), never "": the unique index only skips NULLs.
    def normalize_slug
      self.slug = slug.to_s.parameterize.presence
    end

    def generate_slug_from_title
      return if slug.present?
      self.slug = self.class.generate_slug(collection, title_value_for_slug)
    end

    # The raw value of the collection's title_field, as plain text (rich text
    # is stripped of markup), used to seed an auto-generated slug.
    def title_value_for_slug(source = draft_data)
      field_id = collection&.title_field
      return nil if field_id.blank?

      raw = (source || {})[field_id]
      spec = collection.fields.find { |f| f["id"] == field_id }
      return raw.to_s if spec.nil?

      spec["type"] == "rich_text" ? ActionText::Content.new(raw.to_s).to_plain_text : raw.to_s
    end
  end
end
