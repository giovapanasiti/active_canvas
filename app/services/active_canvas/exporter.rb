require "zip"
require "json"

module ActiveCanvas
  # Builds a self-contained ZIP (manifest.json + media/ files) of the whole instance.
  class Exporter
    FORMAT_VERSION = 2

    PAGE_ATTRS = %w[
      slug title published content content_css content_js content_components
      compiled_tailwind_css show_header show_footer canonical_url template_enabled bindings
      meta_title meta_description meta_robots og_title og_description og_image
      twitter_card twitter_title twitter_description twitter_image structured_data
      created_at updated_at
    ].freeze

    PARTIAL_ATTRS = %w[partial_type name content content_css content_js content_components compiled_css active].freeze
    VERSION_ATTRS = %w[version_number content_before content_after css_before css_after bindings_before bindings_after
                       content_diff content_size_before content_size_after change_summary changed_by
                       created_at updated_at].freeze
    AI_MODEL_ATTRS = %w[model_id provider name family model_type context_window max_tokens
                        input_price_per_million output_price_per_million input_modalities output_modalities
                        supports_functions active].freeze
    COLLECTION_ATTRS = %w[slug name fields].freeze
    COLLECTION_ITEM_ATTRS = %w[slug status published_at data draft_data created_at updated_at].freeze
    COLLECTION_ITEM_VERSION_ATTRS = %w[version_number data changed_by change_summary created_at updated_at].freeze
    FORM_SUBMISSION_ATTRS = %w[form_key data ip user_agent created_at updated_at].freeze

    # Setting keys that reference other exported records by database id rather
    # than by natural key, and so need special handling on both ends: excluded
    # from the generic settings pass-through and resolved separately.
    HOMEPAGE_SETTING_KEY = "homepage_page_id"
    MEDIA_ID_SETTING_KEYS = %w[seo_favicon_media_id seo_default_og_image_media_id].freeze

    def initialize(include_versions: true, include_ai_models: true, include_secrets: true)
      @include_versions = include_versions
      @include_ai_models = include_ai_models
      @include_secrets = include_secrets
    end

    # Writes the zip to `path`. Returns `path`.
    def export_to(path)
      Zip::File.open(path, create: true) do |zip|
        media_entries = write_media(zip)
        manifest = build_manifest(media_entries)
        # .as_json first: JSON.generate/pretty_generate's C generator calls #to_s
        # (not #to_json/#as_json) on values it doesn't natively know, which for a
        # Time silently produces "2024-01-01 00:00:00 UTC" instead of ISO8601 -
        # as_json recursively converts everything to JSON-safe primitives first.
        zip.get_output_stream("manifest.json") { |io| io.write(JSON.pretty_generate(manifest.as_json)) }
      end
      path
    end

    private

    def write_media(zip)
      Media.find_each.filter_map do |media|
        next unless media.file.attached?
        blob = media.file.blob
        zip_path = "media/#{blob.key}__#{blob.filename}"
        zip.get_output_stream(zip_path) { |io| io.write(media.file.download) }
        {
          "source_id" => media.id, "filename" => media.filename, "content_type" => media.content_type,
          "byte_size" => media.byte_size, "metadata" => media.metadata,
          "checksum" => blob.checksum, "file" => zip_path,
          "created_at" => media.created_at, "updated_at" => media.updated_at
        }
      end
    end

    def build_manifest(media_entries)
      pages = Page.includes(:page_type).to_a
      manifest = {
        "meta" => {
          "format_version" => FORMAT_VERSION, "exported_at" => Time.current.iso8601, "app_version" => ActiveCanvas::VERSION,
          # Recorded so the importer can tell, in replace mode, whether a section's
          # absence means "nothing to restore" or "deliberately excluded" - those
          # get different treatment (see Importer#wipe_existing_data).
          "include_versions" => @include_versions, "include_ai_models" => @include_ai_models, "include_secrets" => @include_secrets
        },
        "homepage_page_slug" => homepage_page_slug,
        "homepage_page_source_id" => homepage_page_source_id,
        "settings" => export_settings,
        "page_types" => PageType.all.map { |pt| { "key" => pt.key, "name" => pt.name } },
        "partials" => Partial.all.map { |p| p.slice(*PARTIAL_ATTRS) },
        # "source_id" is the page's id on THIS instance. It is never written as a
        # foreign key anywhere (slugs are the natural key pages are matched by),
        # only used to correlate a page with its OWN versions/redirects/form
        # submissions/homepage setting in this same manifest - which matters
        # because a page's `slug` can be blank (nullable, not unique), so it
        # can't always identify the right page on its own. See Importer#resolve_page.
        "pages" => pages.map { |pg| pg.slice(*PAGE_ATTRS).merge("page_type_key" => pg.page_type.key, "source_id" => pg.id) },
        "page_redirects" => PageRedirect.includes(:page).map { |r| { "from_slug" => r.from_slug, "page_slug" => r.page.slug, "page_source_id" => r.page_id } },
        "collections" => Collection.all.map { |c| c.slice(*COLLECTION_ATTRS) },
        "collection_items" => export_collection_items,
        "form_submissions" => export_form_submissions,
        "media" => media_entries
      }
      if @include_versions
        manifest["page_versions"] = PageVersion.includes(:page).map do |v|
          v.slice(*VERSION_ATTRS).merge("page_slug" => v.page.slug, "page_source_id" => v.page_id)
        end
      end
      manifest["collection_item_versions"] = export_collection_item_versions if @include_versions
      manifest["ai_models"] = AiModel.all.map { |m| m.slice(*AI_MODEL_ATTRS) } if @include_ai_models
      manifest
    end

    def homepage_page_slug
      id = Setting.homepage_page_id
      return nil unless id&.positive?
      Page.find_by(id: id)&.slug
    end

    def homepage_page_source_id
      id = Setting.homepage_page_id
      id&.positive? && Page.exists?(id: id) ? id : nil
    end

    def export_settings
      Setting.all.filter_map do |s|
        next if s.key == HOMEPAGE_SETTING_KEY # exported separately as homepage_page_slug (a natural key)
        next if !@include_secrets && Setting::ENCRYPTED_KEYS.include?(s.key)
        { "key" => s.key, "value" => Setting.get(s.key) }
      end
    end

    def export_collection_items
      CollectionItem.includes(:collection).map do |item|
        item.slice(*COLLECTION_ITEM_ATTRS).merge(
          "source_id" => item.id,
          "collection_slug" => item.collection.slug
        )
      end
    end

    def export_collection_item_versions
      CollectionItemVersion.includes(collection_item: :collection).map do |v|
        v.slice(*COLLECTION_ITEM_VERSION_ATTRS).merge("item_source_id" => v.collection_item_id)
      end
    end

    def export_form_submissions
      FormSubmission.includes(:page).map do |f|
        f.slice(*FORM_SUBMISSION_ATTRS).merge("page_slug" => f.page.slug, "page_source_id" => f.page_id)
      end
    end
  end
end
