require "zip"
require "json"
require "tempfile"
require "set"

module ActiveCanvas
  # Reads an Exporter zip and restores it. mode: :merge (upsert by natural key) or :replace (wipe + import).
  class Importer
    class InvalidArchive < StandardError; end

    MODES = %i[merge replace].freeze

    # Formats this importer can still read. Manifests are additive across
    # versions (new top-level keys default to empty when absent), so an older
    # manifest just imports fewer sections rather than being rejected.
    SUPPORTED_FORMAT_VERSIONS = [ 1, 2 ].freeze

    # Whole-archive cap, checked before the zip is even opened (defends against
    # a huge/zip-bomb-style upload). Distinct from the per-media-entry cap,
    # which reuses config.max_upload_size (the same limit a normal upload gets).
    MAX_ARCHIVE_SIZE = 1.gigabyte

    # manifest.json itself is read fully into memory to be parsed; cap it well
    # below the whole-archive cap so a hostile/corrupt zip can't force a huge
    # JSON.parse before anything else is checked.
    MAX_MANIFEST_SIZE = 50.megabytes

    # A zip with an absurd number of entries is rejected outright rather than
    # walked one by one.
    MAX_ENTRY_COUNT = 10_000

    # Manifest sections expected to be JSON arrays of JSON objects. Checked
    # up front so a malformed manifest (hand-edited or hostile) fails with a
    # clear InvalidArchive message instead of a TypeError/NoMethodError deep
    # inside some import_* method.
    ARRAY_SECTIONS = %w[
      page_types partials pages page_redirects collections collection_items
      form_submissions media page_versions collection_item_versions ai_models settings
    ].freeze

    def initialize(zip_path, mode:)
      raise ArgumentError, "mode must be :merge or :replace" unless MODES.include?(mode)
      @zip_path = zip_path
      @mode = mode
      @media_remap = {}
      @page_remap = {}
      @collection_item_remap = {}
      @dropped_media_ids = Set.new
      @warned_unparseable_components = false
      # Blobs uploaded to the storage service so far during this run (uploads
      # happen outside/before the DB transaction - see `run` - so they must be
      # purged by hand if the transaction later rolls back; storage writes are
      # not undone by ActiveRecord::Base.transaction).
      @uploaded_blobs = []
      @summary = { created: 0, updated: 0, skipped: 0, warnings: [] }
    end

    def run
      enforce_archive_size!
      begin
        Zip::File.open(@zip_path) do |zip|
          @zip = zip
          manifest = read_manifest(zip)
          validate_manifest_shape!(manifest)
          validate_archive!(zip, manifest)
          read_include_flags(manifest)

          blobs_to_delete = []
          begin
            pending_media = preload_media_blobs(manifest["media"] || [])
            ActiveRecord::Base.transaction do
              blobs_to_delete = wipe_existing_data if @mode == :replace
              import_page_types(manifest["page_types"] || [])
              attach_media(pending_media)
              import_pages(manifest["pages"] || [])
              import_partials(manifest["partials"] || [])
              import_page_versions(manifest["page_versions"] || [])
              import_page_redirects(manifest["page_redirects"] || [])
              import_collections(manifest["collections"] || [])
              import_collection_items(manifest["collection_items"] || [])
              import_collection_item_versions(manifest["collection_item_versions"] || [])
              import_form_submissions(manifest["form_submissions"] || [])
              import_settings(manifest)
              import_ai_models(manifest["ai_models"] || [])
            end
          rescue StandardError
            # Whatever failed - inside the transaction (rolled back automatically)
            # or in the pre-transaction upload loop itself - any blob already
            # written to the storage service this run is not part of a committed
            # dataset, so it must be removed by hand.
            purge_uploaded_blobs
            raise
          end
          # Only reached if the transaction COMMITTED: now it is safe to delete the
          # old media files. On rollback this never runs, so original files survive.
          delete_blob_files(blobs_to_delete)
        end
      rescue Zip::Error => e
        raise InvalidArchive, "not a valid zip archive: #{e.message}"
      end
      @summary
    end

    private

    def enforce_archive_size!
      size = File.size(@zip_path)
      raise InvalidArchive, "archive is too large (#{size} bytes, maximum is #{MAX_ARCHIVE_SIZE} bytes)" if size > MAX_ARCHIVE_SIZE
    rescue Errno::ENOENT
      raise InvalidArchive, "archive file not found"
    end

    def read_manifest(zip)
      entry = zip.find_entry("manifest.json") or raise InvalidArchive, "manifest.json missing"
      if entry.size > MAX_MANIFEST_SIZE
        raise InvalidArchive, "manifest.json is too large (#{entry.size} bytes, maximum is #{MAX_MANIFEST_SIZE} bytes)"
      end

      manifest = JSON.parse(entry.get_input_stream.read)
      raise InvalidArchive, "manifest.json must be a JSON object" unless manifest.is_a?(Hash)
      raise InvalidArchive, "manifest.json 'meta' must be a JSON object" unless manifest["meta"].nil? || manifest["meta"].is_a?(Hash)

      version = manifest.dig("meta", "format_version")
      raise InvalidArchive, "unsupported format_version: #{version.inspect}" unless SUPPORTED_FORMAT_VERSIONS.include?(version)
      manifest
    rescue JSON::ParserError => e
      raise InvalidArchive, "invalid manifest.json: #{e.message}"
    end

    # Every top-level section, if present at all, must be an Array of Hashes -
    # not just any old JSON value. Checked once, up front, so a malformed
    # section fails clearly here instead of raising deep inside some
    # import_* method (a TypeError/NoMethodError, which a controller can't
    # tell apart from a real bug).
    def validate_manifest_shape!(manifest)
      ARRAY_SECTIONS.each do |key|
        section = manifest[key]
        next if section.nil?
        raise InvalidArchive, "manifest.json '#{key}' must be a JSON array" unless section.is_a?(Array)
        unless section.all? { |row| row.is_a?(Hash) }
          raise InvalidArchive, "manifest.json '#{key}' must contain JSON objects"
        end
      end
    end

    # Cheap, whole-archive checks that run before a single row is imported:
    # a runaway entry count, duplicate media file references (which would let
    # one physical file impersonate two different source_ids), and a total
    # uncompressed media size cap (a small manifest.json can still point at
    # a zip-bomb-style set of media entries).
    def validate_archive!(zip, manifest)
      if zip.entries.size > MAX_ENTRY_COUNT
        raise InvalidArchive, "archive has too many entries (#{zip.entries.size}, maximum is #{MAX_ENTRY_COUNT})"
      end

      media_rows = manifest["media"] || []
      files = media_rows.map { |r| r["file"] }.compact
      raise InvalidArchive, "manifest references the same media file more than once" if files.uniq.size != files.size

      limit = ActiveCanvas.config.import_max_media_bytes
      total = media_rows.sum do |r|
        entry = zip.find_entry(r["file"].to_s)
        entry ? entry.size : 0
      end
      raise InvalidArchive, "media in this archive is too large in total (#{total} bytes, maximum is #{limit} bytes)" if total > limit
    end

    # Legacy (format_version 1) manifests never recorded these, so absence is
    # treated as "nothing was excluded" - the same assumption those old
    # exports always operated under.
    def read_include_flags(manifest)
      meta = manifest["meta"] || {}
      @include_versions  = meta.fetch("include_versions", true)
      @include_ai_models = meta.fetch("include_ai_models", true)
      @include_secrets   = meta.fetch("include_secrets", true)
    end

    # Deletes all ActiveCanvas data + media DB rows inside the transaction, but does
    # NOT delete the physical blob files (returned for deletion after commit, so a
    # rollback cannot lose the user's original media). ApiTokens are deliberately
    # never touched: they are bearer credentials bound to THIS instance, not part
    # of a portable dataset, and replace mode must not revoke them.
    #
    # A section that was deliberately EXCLUDED from this export (per the meta
    # include flags) is not wiped either: there's nothing in the manifest to
    # replace it with, so the target's existing rows for that section are kept
    # rather than being deleted with nothing to restore them.
    def wipe_existing_data
      warn_about_excluded_version_loss

      media_blobs = []
      Media.find_each { |m| media_blobs << m.file.blob if m.file.attached? }
      media_blob_ids = media_blobs.map(&:id)

      variant_record_ids = defined?(ActiveStorage::VariantRecord) ? ActiveStorage::VariantRecord.where(blob_id: media_blob_ids).pluck(:id) : []
      variant_attachments = ActiveStorage::Attachment.where(record_type: "ActiveStorage::VariantRecord", record_id: variant_record_ids)
      variant_blobs = ActiveStorage::Blob.where(id: variant_attachments.pluck(:blob_id)).to_a

      variant_attachments.delete_all
      ActiveStorage::VariantRecord.where(id: variant_record_ids).delete_all if defined?(ActiveStorage::VariantRecord)
      ActiveStorage::Blob.where(id: variant_blobs.map(&:id)).delete_all

      ActiveStorage::Attachment.where(record_type: "ActiveCanvas::Media", name: "file").delete_all
      ActiveStorage::Blob.where(id: media_blob_ids).delete_all

      [ CollectionItemVersion, CollectionItem, Collection, FormSubmission, PageRedirect, PageVersion, Page, Partial, PageType ].each(&:delete_all)

      if @include_secrets
        Setting.delete_all
      else
        Setting.where.not(key: Setting::ENCRYPTED_KEYS).delete_all
      end
      AiModel.delete_all if @include_ai_models
      Media.delete_all

      media_blobs + variant_blobs
    end

    def warn_about_excluded_version_loss
      return if @include_versions

      page_version_count = PageVersion.count
      item_version_count = CollectionItemVersion.count
      return if page_version_count.zero? && item_version_count.zero?

      @summary[:warnings] << "#{page_version_count} page version(s) and #{item_version_count} collection item version(s) were not " \
        "restored: this export excluded version history, and their pages/items are being replaced"
    end

    def delete_blob_files(blobs)
      blobs.each do |blob|
        blob.service.delete(blob.key)
      rescue StandardError => e
        Rails.logger.warn("[ActiveCanvas] import: could not delete old blob file #{blob.key}: #{e.message}")
      end
    end

    def purge_uploaded_blobs
      @uploaded_blobs.each do |blob|
        blob.purge
      rescue StandardError => e
        Rails.logger.warn("[ActiveCanvas] import: could not purge uploaded blob #{blob.key} after failure: #{e.message}")
      end
      @uploaded_blobs.clear
    end

    def import_page_types(rows)
      rows.each do |r|
        rec = @mode == :merge ? PageType.find_or_initialize_by(key: r["key"]) : PageType.new(key: r["key"])
        track(rec) { rec.update!(name: r["name"]) }
      end
    end

    def import_pages(rows)
      rows.each do |r|
        pt = PageType.find_by(key: r["page_type_key"])
        unless pt
          @summary[:warnings] << "page '#{r["slug"]}' skipped: page_type '#{r["page_type_key"]}' not found"
          @summary[:skipped] += 1
          next
        end
        attrs = strip_nil_timestamps(r.slice(*Exporter::PAGE_ATTRS).except("slug"))
        attrs["content"] = remap_media_refs(attrs["content"])
        attrs["content_components"] = remap_content_components(attrs["content_components"])
        # A blank slug is not a usable natural key (several pages can share it);
        # such a row is always created fresh rather than matched to the wrong page.
        rec = if @mode == :merge && r["slug"].present?
          Page.find_or_initialize_by(slug: r["slug"])
        else
          Page.new(slug: r["slug"])
        end
        rec.page_type = pt
        track(rec) { rec.update!(attrs) }
        @page_remap[r["source_id"]] = rec.id if r["source_id"]
      end
    end

    def import_partials(rows)
      rows.each do |r|
        attrs = r.slice(*Exporter::PARTIAL_ATTRS).except("partial_type")
        attrs["content"] = remap_media_refs(attrs["content"])
        attrs["content_components"] = remap_content_components(attrs["content_components"])
        rec = @mode == :merge ? Partial.find_or_initialize_by(partial_type: r["partial_type"]) : Partial.new(partial_type: r["partial_type"])
        track(rec) { rec.update!(attrs) }
      end
    end

    def import_page_versions(rows)
      return if @mode == :merge # merge keeps the target's own version history; histories don't merge

      rows.each do |r|
        page = resolve_page(r) or next
        page.versions.create!(strip_nil_timestamps(r.slice(*Exporter::VERSION_ATTRS)))
        @summary[:created] += 1
      end
    end

    def import_page_redirects(rows)
      rows.each do |r|
        if @mode == :merge && Page.exists?(slug: r["from_slug"])
          @summary[:warnings] << "redirect '#{r["from_slug"]}' skipped: a page already uses that slug"
          @summary[:skipped] += 1
          next
        end

        page = resolve_page(r)
        unless page
          @summary[:warnings] << "redirect '#{r["from_slug"]}' skipped: target page '#{r["page_slug"]}' not found"
          @summary[:skipped] += 1
          next
        end
        rec = @mode == :merge ? PageRedirect.find_or_initialize_by(from_slug: r["from_slug"]) : PageRedirect.new(from_slug: r["from_slug"])
        rec.page = page
        track(rec) { rec.save! }
      end
    end

    def import_collections(rows)
      rows.each do |r|
        rec = @mode == :merge ? Collection.find_or_initialize_by(slug: r["slug"]) : Collection.new(slug: r["slug"])
        track(rec) { rec.update!(name: r["name"], fields: r["fields"] || []) }
      end
    end

    def import_collection_items(rows)
      rows.each do |r|
        collection = Collection.find_by(slug: r["collection_slug"])
        unless collection
          @summary[:warnings] << "collection item skipped: collection '#{r["collection_slug"]}' not found"
          @summary[:skipped] += 1
          next
        end
        # Items don't require a slug, so a blank one can't be used as a merge key:
        # such rows are always created fresh (never matched to an existing item).
        rec = if @mode == :merge && r["slug"].present?
          CollectionItem.find_or_initialize_by(collection: collection, slug: r["slug"])
        else
          CollectionItem.new(collection: collection)
        end
        attrs = strip_nil_timestamps(
          slug: r["slug"],
          status: r["status"],
          published_at: r["published_at"],
          created_at: r["created_at"],
          updated_at: r["updated_at"],
          data: remap_collection_item_data(collection, r["data"]),
          draft_data: remap_collection_item_data(collection, r["draft_data"])
        )
        track(rec) { rec.update!(attrs) }
        @collection_item_remap[r["source_id"]] = rec.id if r["source_id"]
      end
    end

    # collection_item_versions are historical snapshots, imported verbatim like
    # page_versions (not remapped, and skipped entirely in merge mode: an
    # append-only history doesn't merge with another instance's history).
    def import_collection_item_versions(rows)
      return if @mode == :merge

      rows.each do |r|
        item_id = @collection_item_remap[r["item_source_id"]] or next
        CollectionItemVersion.create!(strip_nil_timestamps(
          collection_item_id: item_id,
          version_number: r["version_number"],
          data: r["data"],
          changed_by: r["changed_by"],
          change_summary: r["change_summary"],
          created_at: r["created_at"],
          updated_at: r["updated_at"]
        ))
        @summary[:created] += 1
      end
    end

    # form_submissions are an append-only log of visitor activity, so (like
    # page/collection-item versions) they are only restored in replace mode.
    def import_form_submissions(rows)
      return if @mode == :merge

      rows.each do |r|
        page = resolve_page(r) or next
        FormSubmission.create!(strip_nil_timestamps(
          page: page, form_key: r["form_key"], data: r["data"], ip: r["ip"], user_agent: r["user_agent"],
          created_at: r["created_at"], updated_at: r["updated_at"]
        ))
        @summary[:created] += 1
      end
    end

    def import_settings(manifest)
      (manifest["settings"] || []).each do |r|
        key = r["key"]
        if key == Exporter::HOMEPAGE_SETTING_KEY
          # Never trusted as a raw id (it's a different instance's primary key);
          # the natural-key form below (homepage_page_slug/source_id) is used instead.
          next
        elsif Exporter::MEDIA_ID_SETTING_KEYS.include?(key)
          import_media_id_setting(key, r["value"])
        else
          existed = Setting.exists?(key: key)
          Setting.set(key, r["value"])
          existed ? @summary[:updated] += 1 : @summary[:created] += 1
        end
      end
      import_homepage_setting(manifest)
    end

    def import_media_id_setting(key, old_value)
      return if old_value.blank?

      new_id = @media_remap[old_value.to_i]
      if new_id
        Setting.set(key, new_id.to_s)
      else
        @summary[:warnings] << "setting '#{key}' cleared: referenced media (id #{old_value}) was not imported"
        Setting.set(key, nil)
      end
      @summary[:updated] += 1
    end

    def import_homepage_setting(manifest)
      slug = manifest["homepage_page_slug"]
      source_id = manifest["homepage_page_source_id"]
      return if slug.blank? && source_id.blank?

      page_id = (source_id && @page_remap[source_id]) || Page.find_by(slug: slug)&.id
      if page_id
        Setting.homepage_page_id = page_id
        @summary[:updated] += 1
      else
        @summary[:warnings] << "homepage setting skipped: page '#{slug}' not found"
      end
    end

    def import_ai_models(rows)
      rows.each do |r|
        rec = @mode == :merge ? AiModel.find_or_initialize_by(model_id: r["model_id"]) : AiModel.new(model_id: r["model_id"])
        track(rec) { rec.update!(r.slice(*Exporter::AI_MODEL_ATTRS).except("model_id")) }
      end
    end

    # Phase 1 (outside/before the DB transaction): upload every accepted media
    # entry's bytes to the storage service and return the [row, blob] pairs to
    # attach in phase 2. Uploads are not transactional - if anything later in
    # the import fails, `run` purges every blob uploaded this call (see
    # `purge_uploaded_blobs`) rather than leaving orphaned files behind a
    # rolled-back transaction.
    def preload_media_blobs(rows)
      max_bytes = ActiveCanvas.config.max_upload_size
      rows.filter_map do |r|
        if @mode == :merge && (existing = find_media_by_checksum(r["checksum"]))
          @media_remap[r["source_id"]] = existing.id
          @summary[:skipped] += 1
          next nil
        end

        zip_path = r["file"].to_s
        raise InvalidArchive, "unsafe media path in manifest: #{zip_path.inspect}" unless safe_media_path?(zip_path)

        entry = @zip.find_entry(zip_path) or raise InvalidArchive, "media file missing from archive: #{zip_path}"
        if entry.size > max_bytes
          @summary[:warnings] << "media '#{r["filename"]}' skipped: file exceeds the #{max_bytes} byte upload limit"
          @summary[:skipped] += 1
          next nil
        end

        blob = upload_blob_from_entry(entry, r)
        @uploaded_blobs << blob
        [ r, blob ]
      end
    end

    # Streams the zip entry through a Tempfile rather than reading it fully
    # into a String/StringIO, so one large media file doesn't hold its whole
    # decompressed size in the Ruby heap at once.
    def upload_blob_from_entry(entry, r)
      tmp = Tempfile.new("ac_import_media", binmode: true)
      begin
        IO.copy_stream(entry.get_input_stream, tmp)
        tmp.rewind
        ActiveStorage::Blob.create_and_upload!(io: tmp, filename: r["filename"], content_type: r["content_type"])
      ensure
        tmp.close!
      end
    end

    # Phase 2 (inside the DB transaction): attach each already-uploaded blob to
    # a new Media record. A row that fails the same acceptable_file validation
    # a normal upload gets is skipped (with a warning) and its blob purged
    # immediately - it was never going to be part of the committed dataset.
    def attach_media(pending)
      pending.each do |r, blob|
        media = Media.new(strip_nil_timestamps(filename: r["filename"], created_at: r["created_at"], updated_at: r["updated_at"]))
        media.file.attach(blob)
        begin
          # Imported media is held to exactly the same content-type / SVG / size
          # rules as a normal admin upload (acceptable_file runs on :create) -
          # a backup zip is not a bypass for those checks.
          media.save!
        rescue ActiveRecord::RecordInvalid => e
          @summary[:warnings] << "media '#{r["filename"]}' (source id #{r["source_id"]}) skipped: #{e.record.errors.full_messages.to_sentence}"
          @summary[:skipped] += 1
          blob.purge
          @uploaded_blobs.delete(blob)
          next
        end
        apply_media_metadata(media, r)
        @media_remap[r["source_id"]] = media.id
        @summary[:created] += 1
      end
    end

    # The freshly-uploaded blob's own metadata (width/height) is often blank
    # right after create_and_upload! (image analysis can run asynchronously),
    # so the metadata captured at export time is applied explicitly instead of
    # relying on re-analysis of the target's blob.
    def apply_media_metadata(media, r)
      return if r["metadata"].blank?
      media.update_column(:metadata, r["metadata"])
    end

    def safe_media_path?(path)
      path.present? && path.start_with?("media/") && !path.include?("..")
    end

    def find_media_by_checksum(checksum)
      return nil if checksum.blank?
      attachment = ActiveStorage::Attachment
        .joins(:blob)
        .find_by(record_type: "ActiveCanvas::Media", name: "file", active_storage_blobs: { checksum: checksum })
      attachment && Media.find_by(id: attachment.record_id)
    end

    # Resolves a manifest row's page reference through the source-id map built
    # while importing pages (works even when the page's slug is blank, which a
    # slug-only lookup couldn't disambiguate), falling back to the slug for a
    # manifest that predates this (the map is simply empty/unpopulated then).
    def resolve_page(r, slug_key: "page_slug", source_key: "page_source_id")
      source_id = r[source_key]
      page_id = source_id && @page_remap[source_id]
      return Page.find_by(id: page_id) if page_id
      Page.find_by(slug: r[slug_key])
    end

    # Rails only auto-stamps a timestamp column with the current time when it
    # wasn't already explicitly assigned - so passing an explicit `nil` (a
    # legacy/incomplete manifest row simply missing "created_at"/"updated_at")
    # would force the NOT NULL column to nil instead of leaving it alone.
    # Used everywhere a manifest row's created_at/updated_at is assigned.
    def strip_nil_timestamps(attrs)
      attrs = attrs.dup
      %w[created_at updated_at].each do |key|
        attrs.delete(key) if attrs.key?(key) && attrs[key].nil?
        sym = key.to_sym
        attrs.delete(sym) if attrs.key?(sym) && attrs[sym].nil?
      end
      attrs
    end

    # Remaps `data-ac-media-id="OLD"` references inside plain HTML text (page &
    # partial `content`, and rich_text collection fields - never JSON, see
    # remap_content_components for the GrapesJS component tree). Per the design
    # spec (§6.3), an id that wasn't imported has its attribute DROPPED rather
    # than left pointing at a stale/foreign id, and is reported once per id in
    # the result summary.
    def remap_media_refs(text)
      return text if text.blank?
      text.gsub(/(\s?)(data-ac-media-id(["']?)\s*[:=]\s*(["']?))(\d+)\4/) do
        leading_space = Regexp.last_match(1)
        prefix        = Regexp.last_match(2)
        old_id        = Regexp.last_match(5).to_i
        new_id        = @media_remap[old_id]
        if new_id
          "#{leading_space}#{prefix}#{new_id}#{Regexp.last_match(4)}"
        else
          note_dropped_media_ref(old_id)
          ""
        end
      end
    end

    MEDIA_ID_JSON_KEY = "data-ac-media-id"

    # content_components is GrapesJS's component tree, serialized as JSON (not
    # HTML) - a text-level gsub over it, as remap_media_refs does for real
    # HTML, risks corrupting the JSON (e.g. turning
    # {"data-ac-media-id":"999","id":"x"} into {","id":"x"} when an id is
    # dropped). Instead: parse it, walk every Hash looking for the
    # "data-ac-media-id" key specifically, remap/delete just that key's value,
    # and re-serialize. A component tree that doesn't even parse as JSON is
    # left completely untouched (better a stale reference than corrupted
    # component data) and warned about once per import.
    def remap_content_components(text)
      return text if text.blank?

      parsed = JSON.parse(text)
      JSON.generate(remap_media_ids_in_json(parsed))
    rescue JSON::ParserError
      unless @warned_unparseable_components
        @warned_unparseable_components = true
        @summary[:warnings] << "content_components could not be parsed as JSON; media references inside it were left unchanged"
      end
      text
    end

    def remap_media_ids_in_json(node)
      case node
      when Hash
        node.each_with_object({}) do |(key, value), acc|
          if key == MEDIA_ID_JSON_KEY
            new_id = remap_media_id(value)
            acc[key] = new_id.to_s if new_id
          else
            acc[key] = remap_media_ids_in_json(value)
          end
        end
      when Array
        node.map { |v| remap_media_ids_in_json(v) }
      else
        node
      end
    end

    # Same drop-and-warn policy as remap_media_refs, for a scalar media id (a
    # collection item's "media"-type field value, or a content_components
    # "data-ac-media-id" JSON value).
    def remap_media_id(value)
      return nil if value.blank?
      old_id = value.to_i
      new_id = @media_remap[old_id]
      return new_id if new_id

      note_dropped_media_ref(old_id)
      nil
    end

    def note_dropped_media_ref(old_id)
      return if @dropped_media_ids.include?(old_id)
      @dropped_media_ids << old_id
      @summary[:warnings] << "dropped a reference to media id #{old_id}: it was not imported"
    end

    def remap_collection_item_data(collection, data)
      return {} if data.blank?
      schema = CollectionSchema.new(collection.fields)
      data.each_with_object({}) do |(field_id, value), acc|
        field_type = schema.field(field_id) && schema.field(field_id)["type"]
        acc[field_id] = case field_type
        when "media" then remap_media_id(value)
        when "rich_text" then remap_media_refs(value)
        else value
        end
      end
    end

    def track(record)
      existed = record.persisted?
      yield
      existed ? @summary[:updated] += 1 : @summary[:created] += 1
    end
  end
end
