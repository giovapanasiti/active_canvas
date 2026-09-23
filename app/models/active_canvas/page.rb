module ActiveCanvas
  class Page < ApplicationRecord
    belongs_to :page_type
    has_many :versions, class_name: "ActiveCanvas::PageVersion", dependent: :destroy
    has_many :redirects, class_name: "ActiveCanvas::PageRedirect", dependent: :destroy
    has_many :form_submissions, class_name: "ActiveCanvas::FormSubmission", dependent: :destroy

    # bindings column is JSON; ensure default and not-null at the model level too.
    attribute :bindings, default: {}

    validates :title, presence: true
    validates :slug, uniqueness: true, allow_blank: true
    validate :bindings_shape

    before_save :set_default_slug
    before_save :normalize_slug
    before_save :sanitize_content_if_enabled
    after_update :create_version_if_content_changed
    after_save :manage_slug_redirects, if: :saved_change_to_slug?

    scope :published, -> { where(published: true) }
    scope :draft, -> { where(published: false) }

    # Thread-local storage for tracking who made the change
    thread_cattr_accessor :current_editor

    def to_param
      id&.to_s
    end

    def rendered_content(form_feedback: nil, form_action: nil)
      rendered = ActiveCanvas::TemplateRenderer.new(self, mode: :public).render
      rendered = ActiveCanvas::ContentRenderer.resolve(rendered).to_s
      ActiveCanvas::FormStamper.new(rendered, page: self, feedback: form_feedback, action: form_action).stamp.html_safe
    end

    def current_version_number
      versions.maximum(:version_number) || 0
    end

    # An unsaved copy carrying the editor's current state, for previews. Same
    # id, so form tokens and media references resolve like the real page.
    # Sanitized the way a save would be, so a static preview never shows raw
    # markup that saving would have stripped.
    def preview_with(content: nil, bindings: nil, content_css: nil, content_js: nil, template_enabled: nil)
      dup.tap do |preview|
        preview.id = id
        preview.content = content unless content.nil?
        preview.bindings = bindings unless bindings.nil?
        preview.content_css = content_css unless content_css.nil?
        preview.content_js = content_js unless content_js.nil?
        preview.template_enabled = template_enabled unless template_enabled.nil?
        preview.sanitize_content_if_enabled
      end
    end

    # Header/footer display (with fallback for when columns don't exist yet)
    def show_header?
      return true unless self.class.column_names.include?("show_header")
      show_header != false
    end

    def show_footer?
      return true unless self.class.column_names.include?("show_footer")
      show_footer != false
    end

    private

    def set_default_slug
      self.slug = "active_canvas_id_#{id}" if slug.blank? && persisted?
    end

    def normalize_slug
      self.slug = slug.parameterize if slug.present?
    end

    # bindings is `{ "name" => { "source" => "...", ... } }`. Anything else
    # would blow up inside BindingResolver on the public page, so refuse it here.
    def bindings_shape
      return errors.add(:bindings, "must be a JSON object") unless bindings.is_a?(Hash)

      bindings.each do |name, spec|
        source = spec.is_a?(Hash) ? (spec["source"] || spec[:source]) : nil
        errors.add(:bindings, "entry #{name.to_s.inspect} must be an object with a source") if source.to_s.blank?
      end
    end

    protected

    # Dynamic pages are sanitized after Liquid renders (see TemplateRenderer):
    # sanitizing the source would move tags out of tables and mangle `<`.
    # When dynamic rendering is switched off, the stored content is sanitized
    # on that save so nothing unsanitized is ever served raw. Also called by
    # `preview_with` on another instance, so it must be protected, not private.
    def sanitize_content_if_enabled
      return unless ActiveCanvas.config.sanitize_content

      if !template_enabled? && (content_changed? || template_enabled_changed?)
        self.content = ContentSanitizer.sanitize_html(content)
      end

      if content_css_changed?
        self.content_css = ContentSanitizer.sanitize_css(content_css)
      end
    end

    private

    def create_version_if_content_changed
      content_changed_now  = saved_change_to_content?
      css_changed_now      = saved_change_to_content_css?
      bindings_changed_now = saved_change_to_bindings?
      return unless content_changed_now || css_changed_now || bindings_changed_now

      versions.create!(
        content_before:  content_before_last_save,
        content_after:   content,
        css_before:      content_css_before_last_save,
        css_after:       content_css,
        bindings_before: bindings_before_last_save,
        bindings_after:  bindings,
        changed_by:      self.class.current_editor,
        change_summary:  generate_change_summary
      )
    end

    def generate_change_summary
      changes = []
      changes << "content updated"  if saved_change_to_content?
      changes << "CSS updated"      if saved_change_to_content_css?
      changes << "bindings updated" if saved_change_to_bindings?
      changes.join(", ").presence || "Updated"
    end

    def manage_slug_redirects
      old_slug, new_slug = saved_change_to_slug

      # A slug now owned by a real page must not redirect elsewhere.
      PageRedirect.where(from_slug: new_slug).delete_all if new_slug.present?

      return unless published? && old_slug.present?

      redirect = PageRedirect.find_or_initialize_by(from_slug: old_slug)
      redirect.update!(page: self)
    end
  end
end
