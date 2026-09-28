module ActiveCanvas
  class Collection < ApplicationRecord
    RESERVED_SLUGS = %w[_literal].freeze
    # Keys CollectionSource puts on every row; a field may not shadow them.
    # "_seo" is the reserved per-item SEO data key (Part 3): it lives outside
    # the fields namespace entirely, so a field may not claim it either.
    RESERVED_FIELD_IDS = %w[id slug published_at _seo].freeze
    # Row keys only a collection with public pages adds (item.url, item.seo).
    # Reserved only while has_pages is on, so a collection created before
    # public pages existed keeps a `url`/`seo` field until it opts in.
    PAGES_RESERVED_FIELD_IDS = %w[url seo].freeze
    FIELD_ID_FORMAT = /\A[a-z][a-z0-9_]*\z/

    # Top-level routes that a collection with public pages can't shadow with
    # its slug (see config/routes.rb: mcp, admin namespace, forms, /sitemap.xml, /robots.txt).
    RESERVED_PATHS = %w[mcp sitemap.xml robots.txt admin forms].freeze

    # Field types accepted by title_field / description_field (rich text is
    # stripped to plain text for SEO / slug generation) and by image_field.
    TEXT_LIKE_FIELD_TYPES = %w[text textarea rich_text].freeze
    MEDIA_FIELD_TYPES = %w[media].freeze
    FIELD_REFERENCE_ATTRIBUTES = {
      "title_field" => TEXT_LIKE_FIELD_TYPES,
      "description_field" => TEXT_LIKE_FIELD_TYPES,
      "image_field" => MEDIA_FIELD_TYPES
    }.freeze

    has_many :items, class_name: "ActiveCanvas::CollectionItem", dependent: :destroy
    has_many :template_pages, class_name: "ActiveCanvas::Page", foreign_key: :collection_id, dependent: :destroy, inverse_of: :collection

    attribute :fields, default: []

    before_validation :normalize_slug
    before_validation :assign_missing_field_ids

    validates :name, presence: true
    validates :slug, presence: true, uniqueness: true
    validates :per_page, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 100 }
    validate :slug_not_reserved
    validate :fields_well_formed
    validate :field_references_valid
    validate :has_pages_slug_availability, if: :has_pages?

    after_save :ensure_templates!, if: -> { saved_change_to_has_pages? && has_pages? }
    after_save :backfill_item_slugs!, if: -> { saved_change_to_has_pages? && has_pages? }

    scope :with_pages, -> { where(has_pages: true) }
    scope :in_sidebar, -> { where(show_in_sidebar: true) }

    def item_name
      ActiveCanvas::DataSources.item_name(slug)
    end

    # ensure_templates! — Task 3
    # Creates the two template pages (Part 4 "Model") a collection needs to
    # have public pages: one `index`, one `show`, each seeded with a starter
    # design (CollectionTemplateStarter) that already renders against the
    # implicit assigns (CollectionPageContext). Idempotent: safe to call every
    # time `has_pages` is turned on, on create or update.
    def ensure_templates!
      %w[index show].each do |role|
        next if template_pages.exists?(collection_role: role)

        template_pages.create!(
          title: "#{name} — #{role == "index" ? "Index" : "Item"} template",
          page_type: ActiveCanvas::PageType.default,
          collection_role: role,
          template_enabled: true,
          content: ActiveCanvas::CollectionTemplateStarter.html_for(self, role)
        )
      end
    end
    # /ensure_templates! — Task 3

    # Items created while the collection had no public pages may have no
    # slug; every item of a collection with pages needs one (show URL,
    # sitemap, index links).
    def backfill_item_slugs!
      items.where(slug: [ nil, "" ]).order(:id).each(&:backfill_slug!)
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
      self.fields = json.blank? ? [] : JSON.parse(json)
    rescue JSON::ParserError, TypeError
      @fields_unreadable = true
    end

    def fields_json
      (fields.is_a?(Array) ? fields : []).to_json
    end

    def fields=(value)
      @fields_unreadable = false
      super
    end

    private

    def normalize_slug
      self.slug = (slug.presence || name).to_s.parameterize
    end

    def assign_missing_field_ids
      return unless fields_readable?

      taken = RESERVED_FIELD_IDS + PAGES_RESERVED_FIELD_IDS
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
      !@fields_unreadable && fields.is_a?(Array) && fields.all?(Hash)
    end

    def field_references_valid
      FIELD_REFERENCE_ATTRIBUTES.each do |attribute, allowed_types|
        value = public_send(attribute)
        next if value.blank?

        spec = fields_readable? ? fields.find { |f| f["id"] == value } : nil
        if spec.nil?
          errors.add(attribute, "references an unknown field")
        elsif !allowed_types.include?(spec["type"])
          errors.add(attribute, "must reference a #{allowed_types.join(" or ")} field")
        end
      end
    end

    # Only enforced when has_pages (see the validate call above): the
    # collection's public index would otherwise shadow a real page/redirect
    # or a top-level engine route.
    def has_pages_slug_availability
      return if slug.blank?

      if RESERVED_PATHS.include?(slug)
        errors.add(:slug, "is a reserved path and can't be used for public pages")
      elsif ActiveCanvas::Page.regular.where(slug: slug).exists?
        errors.add(:slug, "is already used by a page")
      elsif ActiveCanvas::PageRedirect.where(from_slug: slug).exists?
        errors.add(:slug, "is already used by a page redirect")
      end
    end

    def fields_well_formed
      return errors.add(:fields, "could not be read") unless fields_readable?

      seen = []
      fields.each do |field|
        errors.add(:fields, "must each have a label") if field["label"].blank?
        errors.add(:fields, "have an unknown type: #{field["type"]}") unless CollectionSchema::VALID_FIELD_TYPES.include?(field["type"])
        errors.add(:fields, "have an invalid id: #{field["id"]} (ids are lower_snake_case; remove the field and add it again)") unless field["id"].to_s.match?(FIELD_ID_FORMAT)
        errors.add(:fields, "use a reserved id: #{field["id"]}") if RESERVED_FIELD_IDS.include?(field["id"])
        if has_pages? && PAGES_RESERVED_FIELD_IDS.include?(field["id"])
          errors.add(:fields, "use the id \"#{field["id"]}\", which public pages reserve for item.#{field["id"]}; " \
            "remove that field (or turn public pages off) first")
        end
        errors.add(:fields, "have duplicate ids: #{field["id"]}") if seen.include?(field["id"])
        seen << field["id"]
      end
    end
  end
end
