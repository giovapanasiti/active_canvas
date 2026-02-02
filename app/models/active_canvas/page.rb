module ActiveCanvas
  class Page < ApplicationRecord
    belongs_to :page_type

    validates :title, presence: true
    validates :slug, uniqueness: true, allow_blank: true

    before_save :set_default_slug
    before_save :normalize_slug

    scope :published, -> { where(published: true) }
    scope :draft, -> { where(published: false) }

    def to_param
      id&.to_s
    end

    def rendered_content
      content.to_s.html_safe
    end

    private

    def set_default_slug
      self.slug = "active_canvas_id_#{id}" if slug.blank? && persisted?
    end

    def normalize_slug
      self.slug = slug.parameterize if slug.present?
    end
  end
end
