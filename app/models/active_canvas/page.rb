module ActiveCanvas
  class Page < ApplicationRecord
    belongs_to :page_type
    has_many :versions, class_name: "ActiveCanvas::PageVersion", dependent: :destroy

    validates :title, presence: true
    validates :slug, uniqueness: true, allow_blank: true

    before_save :set_default_slug
    before_save :normalize_slug
    after_update :create_version_if_content_changed

    scope :published, -> { where(published: true) }
    scope :draft, -> { where(published: false) }

    # Thread-local storage for tracking who made the change
    thread_cattr_accessor :current_editor

    def to_param
      id&.to_s
    end

    def rendered_content
      content.to_s.html_safe
    end

    def current_version_number
      versions.maximum(:version_number) || 0
    end

    private

    def set_default_slug
      self.slug = "active_canvas_id_#{id}" if slug.blank? && persisted?
    end

    def normalize_slug
      self.slug = slug.parameterize if slug.present?
    end

    def create_version_if_content_changed
      return unless saved_change_to_content? || saved_change_to_content_css?

      versions.create!(
        content_before: content_before_last_save,
        content_after: content,
        css_before: content_css_before_last_save,
        css_after: content_css,
        changed_by: self.class.current_editor,
        change_summary: generate_change_summary
      )
    end

    def generate_change_summary
      changes = []
      changes << "content updated" if saved_change_to_content?
      changes << "CSS updated" if saved_change_to_content_css?
      changes.join(", ").presence || "Updated"
    end
  end
end
