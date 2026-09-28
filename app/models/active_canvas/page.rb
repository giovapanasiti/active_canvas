module ActiveCanvas
  class Page < ApplicationRecord
    belongs_to :page_type
    belongs_to :collection, class_name: "ActiveCanvas::Collection", optional: true
    has_many :versions, class_name: "ActiveCanvas::PageVersion", dependent: :destroy
    has_many :redirects, class_name: "ActiveCanvas::PageRedirect", dependent: :destroy
    has_many :form_submissions, class_name: "ActiveCanvas::FormSubmission", dependent: :destroy

    # bindings column is JSON; ensure default and not-null at the model level too.
    attribute :bindings, default: {}

    # Extra Liquid assigns merged over the page's bindings on render (Part 4
    # "Implicit assigns"); transient, never persisted. A template page's
    # public/preview renderer sets this to the `item`/`items`/`collection`/
    # `pagination` context (TemplateEditorContext, CollectionPageContext)
    # before calling `rendered_content`. nil (the default) renders with no
    # extra context, unchanged from a regular page.
    attr_accessor :liquid_context

    validates :title, presence: true
    validates :slug, uniqueness: true, allow_blank: true
    validates :collection_role, inclusion: { in: %w[index show] }, allow_nil: true
    validate :bindings_shape
    validate :slug_not_used_by_a_collection_with_pages

    before_save :set_default_slug
    before_save :normalize_slug
    before_save :sanitize_content_if_enabled
    before_validation :normalize_template_attributes
    before_destroy :refuse_direct_template_destroy
    after_update :create_version_if_content_changed
    after_save :manage_slug_redirects, if: :saved_change_to_slug?

    scope :published, -> { where(published: true) }
    scope :draft, -> { where(published: false) }
    # A "template page" (Part 4: Model) belongs to a collection (`collection_id`
    # present) and is never routed by slug. Regular pages are everything else:
    # the admin pages list, public `:slug` routing, homepage selection and the
    # sitemap page list all use this scope.
    scope :regular, -> { where(collection_id: nil) }

    # A template page (`collection_id` present).
    def template?
      collection_id.present?
    end

    def to_param
      id&.to_s
    end

    # `context:` (Part 4 "Implicit assigns") is extra Liquid assigns merged over
    # the page's own bindings -- how a collection's template pages get their
    # `item`/`items`/`collection`/`pagination` names (CollectionPageContext).
    # When not passed, the transient `liquid_context` set by the editor
    # preview path (TemplateEditorContext) is used.
    def rendered_content(form_feedback: nil, form_action: nil, context: nil)
      rendered = ActiveCanvas::TemplateRenderer.new(self, mode: :public, context: context || liquid_context || {}).render
      rendered = ActiveCanvas::ContentRenderer.resolve(rendered).to_s
      ActiveCanvas::FormStamper.new(rendered, page: self, feedback: form_feedback, action: form_action).stamp.html_safe
    end

    def current_version_number
      versions.maximum(:version_number) || 0
    end

    # Sets content/css/bindings back to an earlier version's *_after values,
    # through the same validation/Tailwind pipeline as any other content
    # update. History is append-only: this creates a new version rather than
    # deleting the ones after it. content_js and template_enabled are not
    # versioned, so restoring never touches them.
    #
    # A version saved before the bindings migration has a nil bindings_after
    # (the column didn't exist yet). Omitting the `bindings` key rather than
    # passing nil keeps the page's current bindings as-is instead of wiping
    # them out on restore.
    def restore_version!(version, keep_components: false)
      attrs = { content: version.content_after, content_css: version.css_after }
      attrs[:bindings] = version.bindings_after unless version.bindings_after.nil?

      ActiveCanvas::PageContentUpdate.call(self, attrs, keep_components: keep_components)
    end

    # An unsaved copy carrying the editor's current state, for previews. Same
    # id, so form tokens and media references resolve like the real page.
    # Sanitized the way a save would be, so a static preview never shows raw
    # markup that saving would have stripped.
    def preview_with(content: nil, bindings: nil, content_css: nil, content_js: nil, template_enabled: nil)
      # dup marks every attribute dirty, so the sanitizer below re-runs on the copy; that is idempotent and intended.
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
      return if collection_id.present? # a template page is never routed by slug

      self.slug = "active_canvas_id_#{id}" if slug.blank? && persisted?
    end

    def normalize_slug
      self.slug = slug.parameterize if slug.present?
    end

    # ensure_templates! — Task 3
    # A template page is never routed by slug and always renders dynamically:
    # force both regardless of what a caller (form, MCP tool) sends.
    def normalize_template_attributes
      return unless collection_id.present?

      self.slug = nil
      self.template_enabled = true
    end

    # Templates are only removed as a side effect of their collection being
    # destroyed (Collection has_many :template_pages, dependent: :destroy),
    # which Rails marks via `destroyed_by_association`. A direct destroy
    # (UI, delete_page) is refused instead.
    def refuse_direct_template_destroy
      return unless collection_id.present?
      return if destroyed_by_association.present?

      errors.add(:base, "Template pages are removed with their collection")
      throw :abort
    end
    # /ensure_templates! — Task 3

    # bindings is `{ "name" => { "source" => "...", ... } }`. Anything else
    # would blow up inside BindingResolver on the public page, so refuse it here.
    def bindings_shape
      return errors.add(:bindings, "must be a JSON object") unless bindings.is_a?(Hash)

      bindings.each do |name, spec|
        source = spec.is_a?(Hash) ? (spec["source"] || spec[:source]) : nil
        errors.add(:bindings, "entry #{name.to_s.inspect} must be an object with a source") if source.to_s.blank?
      end
    end

    # The reverse of Collection#has_pages_slug_availability: a collection with
    # public pages owns its slug, so no regular page may claim it.
    def slug_not_used_by_a_collection_with_pages
      return if slug.blank?
      # Compare what will be stored: normalize_slug parameterizes before save.
      return unless ActiveCanvas::Collection.where(has_pages: true, slug: slug.to_s.parameterize).exists?

      errors.add(:slug, "is used by a collection with public pages")
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
        changed_by:      Current.editor,
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
