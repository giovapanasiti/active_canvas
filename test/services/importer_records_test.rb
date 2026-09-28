require "test_helper"

module ActiveCanvas
  class ImporterRecordsTest < ActiveSupport::TestCase
    def export_now(**opts)
      path = File.join(Dir.tmpdir, "ac_imp_#{SecureRandom.hex(8)}.zip")
      ActiveCanvas::Exporter.new(**opts).export_to(path)
      path
    end

    def seed!
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      ActiveCanvas::Page.create!(title: "Home", slug: "home", published: true, page_type: pt, content: "<p>home</p>")
      ActiveCanvas::Partial.create!(partial_type: "header", name: "Header", content: "<header>x</header>")
      ActiveCanvas::Setting.global_css = "body{color:red}"
    end

    test "replace mode wipes then restores an exact clone" do
      seed!
      zip = export_now

      ActiveCanvas::Page.create!(title: "Extra", slug: "extra", published: false, page_type: ActiveCanvas::PageType.first)

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      assert_equal %w[home], ActiveCanvas::Page.order(:slug).pluck(:slug)
      assert_equal "Default", ActiveCanvas::PageType.find_by(key: "default").name
      assert_equal "Header", ActiveCanvas::Partial.find_by(partial_type: "header").name
      assert_equal "body{color:red}", ActiveCanvas::Setting.global_css
    end

    test "merge mode updates existing by natural key and creates new" do
      seed!
      zip = export_now

      ActiveCanvas::Page.find_by(slug: "home").update!(title: "Changed")

      ActiveCanvas::Importer.new(zip, mode: :merge).run

      assert_equal "Home", ActiveCanvas::Page.find_by(slug: "home").title, "existing page updated from manifest"
      assert_equal 1, ActiveCanvas::Page.where(slug: "home").count, "no duplicate"
    end

    test "merge import of a page that has version history does not raise" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      page = ActiveCanvas::Page.create!(title: "Home", slug: "home", published: true, page_type: pt, content: "<p>v1</p>")
      page.update!(content: "<p>v2</p>") # creates a PageVersion (version_number 1)
      assert page.versions.exists?, "precondition: page has at least one version"
      zip = export_now

      # Change the target so the merge update fires the version callback again
      page.update!(content: "<p>local change</p>")

      assert_nothing_raised do
        ActiveCanvas::Importer.new(zip, mode: :merge).run
      end
      assert_equal "<p>v2</p>", ActiveCanvas::Page.find_by(slug: "home").content
    end

    test "missing media file in archive raises InvalidArchive without losing existing data" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      media = build_saved_media(filename: "logo.png")
      original_bytes = media.file.download
      zip = export_now

      # Corrupt the archive: drop the media file entry but keep its manifest record
      require "zip"
      media_path = nil
      Zip::File.open(zip) do |z|
        manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
        media_path = manifest["media"].first["file"]
      end
      Zip::File.open(zip) { |z| z.remove(z.find_entry(media_path)) }

      assert_raises(ActiveCanvas::Importer::InvalidArchive) do
        ActiveCanvas::Importer.new(zip, mode: :replace).run
      end
      # Original media survived the rolled-back replace (file not physically deleted)
      assert_equal original_bytes, ActiveCanvas::Media.find_by(id: media.id)&.file&.download
    end

    test "invalid manifest version is rejected with no partial writes" do
      seed!
      zip = export_now
      require "zip"
      Zip::File.open(zip) do |z|
        manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
        manifest["meta"]["format_version"] = 999
        z.get_output_stream("manifest.json") { |io| io.write(JSON.generate(manifest)) }
      end

      before = ActiveCanvas::Page.count
      assert_raises(ActiveCanvas::Importer::InvalidArchive) do
        ActiveCanvas::Importer.new(zip, mode: :replace).run
      end
      assert_equal before, ActiveCanvas::Page.count, "no rows deleted on invalid import"
    end

    test "a legacy format_version 1 manifest (no new sections) still imports cleanly" do
      seed!
      zip = export_now
      require "zip"
      Zip::File.open(zip) do |z|
        manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
        manifest["meta"]["format_version"] = 1
        manifest.delete("collections")
        manifest.delete("collection_items")
        manifest.delete("collection_item_versions")
        manifest.delete("page_redirects")
        manifest.delete("form_submissions")
        manifest.delete("homepage_page_slug")
        z.get_output_stream("manifest.json") { |io| io.write(JSON.generate(manifest)) }
      end

      assert_nothing_raised { ActiveCanvas::Importer.new(zip, mode: :replace).run }
      assert_equal %w[home], ActiveCanvas::Page.pluck(:slug)
    end

    test "archive larger than the size cap is rejected before it is opened" do
      seed!
      zip = export_now
      # Sparse-extend the file past the cap (no need for the zip to stay valid:
      # the size check runs, and raises, before the zip is ever opened).
      File.truncate(zip, ActiveCanvas::Importer::MAX_ARCHIVE_SIZE + 1)

      assert_raises(ActiveCanvas::Importer::InvalidArchive) do
        ActiveCanvas::Importer.new(zip, mode: :replace).run
      end
    end

    test "a media path escaping the media/ folder is rejected" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      media = build_saved_media(filename: "logo.png")
      zip = export_now
      require "zip"
      Zip::File.open(zip) do |z|
        manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
        manifest["media"].first["file"] = "../../../tmp/evil"
        z.get_output_stream("manifest.json") { |io| io.write(JSON.generate(manifest)) }
      end

      assert_raises(ActiveCanvas::Importer::InvalidArchive) do
        ActiveCanvas::Importer.new(zip, mode: :replace).run
      end
    end

    test "imported media is held to the same content-type rules as a normal upload" do
      media = with_config(allow_svg_uploads: true) { build_saved_media(filename: "icon.svg", content_type: "image/svg+xml") }
      zip = export_now # source instance allowed SVGs

      summary = ActiveCanvas::Importer.new(zip, mode: :replace).run # target instance: default config (SVG disabled)

      assert_equal 0, ActiveCanvas::Media.count, "the SVG was rejected, not faithfully restored"
      assert(summary[:warnings].any? { |w| w.include?("icon.svg") })
    end

    test "replace mode never deletes ApiTokens" do
      seed!
      token, _plaintext = ActiveCanvas::ApiToken.issue!(name: "agent", scopes: %w[read])
      zip = export_now

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      assert ActiveCanvas::ApiToken.exists?(token.id), "ApiTokens are instance credentials, never part of the portable dataset"
    end

    test "collections, items, redirects and form submissions round-trip in replace mode" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      page = ActiveCanvas::Page.create!(title: "Home", slug: "home", published: true, page_type: pt)
      page.update!(slug: "home2") # leaves a PageRedirect "home" -> page
      ActiveCanvas::FormSubmission.create!(page: page, form_key: "contact", data: { "email" => "a@b.c" })
      collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
      item = collection.items.create!
      item.assign_fields("name" => "Ada")
      item.save!
      item.publish!
      zip = export_now

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      assert_equal "home2", ActiveCanvas::PageRedirect.find_by(from_slug: "home").page.slug
      assert_equal "contact", ActiveCanvas::FormSubmission.first.form_key
      new_collection = ActiveCanvas::Collection.find_by(slug: "team")
      assert_equal "Team", new_collection.name
      new_item = new_collection.items.first
      assert_equal "Ada", new_item.data["name"]
      assert_equal 1, new_item.versions.count
    end

    test "merge mode does not re-import collection item version history or form submissions" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      page = ActiveCanvas::Page.create!(title: "Home", slug: "home", published: true, page_type: pt)
      ActiveCanvas::FormSubmission.create!(page: page, form_key: "contact", data: {})
      collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
      item = collection.items.create!
      item.assign_fields("name" => "Ada")
      item.save!
      item.publish!
      zip = export_now

      ActiveCanvas::Importer.new(zip, mode: :merge).run

      assert_equal 1, ActiveCanvas::FormSubmission.count, "form submissions are an append-only log; merge does not duplicate"
      assert_equal 1, ActiveCanvas::CollectionItemVersion.count, "version history is append-only; merge does not duplicate"
    end

    test "homepage setting and SEO media-id settings are remapped to the target instance's ids" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      page = ActiveCanvas::Page.create!(title: "Home", slug: "home", published: true, page_type: pt)
      media = build_saved_media(filename: "favicon.png")
      ActiveCanvas::Setting.homepage_page_id = page.id
      ActiveCanvas::Setting.seo_favicon_media_id = media.id
      zip = export_now

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      new_page = ActiveCanvas::Page.find_by(slug: "home")
      new_media = ActiveCanvas::Media.order(:id).last
      assert_equal new_page.id, ActiveCanvas::Setting.homepage_page_id
      assert_equal new_media.id, ActiveCanvas::Setting.seo_favicon_media_id
    end

    test "replace mode keeps the target's own secrets and AI models when they were excluded from the export" do
      seed!
      ActiveCanvas::Setting.ai_openai_api_key = "sk-source"
      ActiveCanvas::AiModel.create!(model_id: "source-model", provider: "openai", name: "Source Model")
      zip = export_now(include_secrets: false, include_ai_models: false)

      # Simulate importing into a different instance: it never had the source's
      # own secret/AI model to begin with, only its own.
      ActiveCanvas::AiModel.delete_all
      ActiveCanvas::Setting.ai_openai_api_key = "sk-target-keep-me"
      ActiveCanvas::AiModel.create!(model_id: "target-model", provider: "openai", name: "Target Model")

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      assert_equal "sk-target-keep-me", ActiveCanvas::Setting.ai_openai_api_key, "target's own secret survives when the export excluded secrets"
      assert ActiveCanvas::AiModel.exists?(model_id: "target-model"), "target's own AI model survives when the export excluded AI models"
      refute ActiveCanvas::AiModel.exists?(model_id: "source-model")
    end

    test "replace mode warns (but still replaces the pages/items) when version history was excluded" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      page = ActiveCanvas::Page.create!(title: "Home", slug: "home", page_type: pt, content: "<p>v1</p>")
      page.update!(content: "<p>v2</p>")
      assert page.versions.exists?
      zip = export_now(include_versions: false)

      summary = ActiveCanvas::Importer.new(zip, mode: :replace).run

      assert_equal 0, ActiveCanvas::PageVersion.count
      assert(summary[:warnings].any? { |w| w.include?("version history") })
    end

    test "an oversized manifest.json is rejected" do
      seed!
      zip = export_now
      require "zip"
      Zip::File.open(zip) do |z|
        z.get_output_stream("manifest.json") { |io| io.write("a" * (ActiveCanvas::Importer::MAX_MANIFEST_SIZE + 1)) }
      end

      before = ActiveCanvas::Page.count
      assert_raises(ActiveCanvas::Importer::InvalidArchive) do
        ActiveCanvas::Importer.new(zip, mode: :replace).run
      end
      assert_equal before, ActiveCanvas::Page.count
    end

    test "duplicate media file references in the manifest are rejected" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      build_saved_media(filename: "a.png")
      build_saved_media(filename: "b.png")
      zip = export_now
      require "zip"
      Zip::File.open(zip) do |z|
        manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
        manifest["media"][1]["file"] = manifest["media"][0]["file"]
        z.get_output_stream("manifest.json") { |io| io.write(JSON.generate(manifest)) }
      end

      assert_raises(ActiveCanvas::Importer::InvalidArchive) do
        ActiveCanvas::Importer.new(zip, mode: :replace).run
      end
    end

    test "a non-hash manifest.json (or a corrupt zip) is rejected as InvalidArchive" do
      seed!
      zip = export_now
      require "zip"
      Zip::File.open(zip) { |z| z.get_output_stream("manifest.json") { |io| io.write("[1,2,3]") } }

      assert_raises(ActiveCanvas::Importer::InvalidArchive) do
        ActiveCanvas::Importer.new(zip, mode: :replace).run
      end
    end

    test "a content reference to media that was not imported is dropped, and a warning is recorded" do
      pt = default_page_type
      svg = with_config(allow_svg_uploads: true) { build_saved_media(filename: "icon.svg", content_type: "image/svg+xml") }
      ActiveCanvas::Page.create!(
        title: "Home", slug: "home", published: true, page_type: pt,
        content: %(<p>hi</p><img data-ac-media-id="#{svg.id}" src="/x.svg">)
      )
      zip = export_now

      summary = ActiveCanvas::Importer.new(zip, mode: :replace).run

      page = ActiveCanvas::Page.find_by(slug: "home")
      refute_includes page.content, "data-ac-media-id"
      assert_includes page.content, "<p>hi</p>"
      assert(summary[:warnings].any? { |w| w.include?("dropped a reference to media id #{svg.id}") })
    end

    test "a collection item's media field referencing unimported media is nulled, and a warning is recorded" do
      svg = with_config(allow_svg_uploads: true) { build_saved_media(filename: "icon.svg", content_type: "image/svg+xml") }
      collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Photo", "type" => "media" } ])
      item = collection.items.create!
      item.assign_fields("photo" => svg.id.to_s)
      item.save!
      item.publish!
      zip = export_now

      summary = ActiveCanvas::Importer.new(zip, mode: :replace).run

      new_item = ActiveCanvas::Collection.find_by(slug: "team").items.first
      assert_nil new_item.data["photo"]
      assert(summary[:warnings].any? { |w| w.include?("dropped a reference to media id #{svg.id}") })
    end

    test "a failure later in the manifest purges the media blobs already uploaded this run" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      ActiveCanvas::Page.create!(title: "Home", slug: "home", published: true, page_type: pt)
      build_saved_media(filename: "logo.png")
      zip = export_now

      require "zip"
      Zip::File.open(zip) do |z|
        manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
        manifest["pages"].first["title"] = "" # blank title fails Page's presence validation, later in import order than media
        z.get_output_stream("manifest.json") { |io| io.write(JSON.generate(manifest)) }
      end

      storage_root = Rails.root.join("tmp/storage")
      files_before = Dir.glob(storage_root.join("**/*")).count { |f| File.file?(f) }

      assert_raises(ActiveRecord::RecordInvalid) do
        ActiveCanvas::Importer.new(zip, mode: :replace).run
      end

      files_after = Dir.glob(storage_root.join("**/*")).count { |f| File.file?(f) }
      assert_equal files_before, files_after, "the newly uploaded media blob's file must be purged, not left orphaned on disk"
    end

    test "pages with a blank slug are never matched via find_by(slug: nil) on merge" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      existing_blank = ActiveCanvas::Page.create!(title: "Existing blank-slug page", page_type: pt)
      assert_nil existing_blank.slug, "precondition: a page saved once with no slug stays blank"

      ActiveCanvas::Page.create!(title: "Home", slug: "home", page_type: pt)
      zip = export_now
      require "zip"
      Zip::File.open(zip) do |z|
        manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
        manifest["pages"] << manifest["pages"].first.merge("slug" => nil, "title" => "From manifest, blank slug")
        z.get_output_stream("manifest.json") { |io| io.write(JSON.generate(manifest)) }
      end

      ActiveCanvas::Importer.new(zip, mode: :merge).run

      assert_equal "Existing blank-slug page", ActiveCanvas::Page.find(existing_blank.id).title,
        "a pre-existing blank-slug page must not be overwritten by an unrelated blank-slug manifest row"
      assert ActiveCanvas::Page.exists?(title: "From manifest, blank slug")
    end

    test "merge mode skips a redirect whose from_slug equals an existing page's slug" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      page_a = ActiveCanvas::Page.create!(title: "A", slug: "a", published: true, page_type: pt)
      page_a.update!(slug: "a-renamed") # leaves a PageRedirect "a" -> page_a
      zip = export_now

      # On the target, a different page has since taken over slug "a"
      ActiveCanvas::Page.create!(title: "Unrelated", slug: "a", published: true, page_type: pt)

      summary = ActiveCanvas::Importer.new(zip, mode: :merge).run

      refute ActiveCanvas::PageRedirect.exists?(from_slug: "a"), "a redirect must never shadow a real page's slug"
      assert(summary[:warnings].any? { |w| w.include?("redirect 'a' skipped") })
    end

    test "import fails validation, and rolls back, when a has_pages collection's slug collides with a redirect from the same manifest" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      page = ActiveCanvas::Page.create!(title: "Home", slug: "home", published: true, page_type: pt)
      page.update!(slug: "home2") # leaves a PageRedirect "home" -> page
      zip = export_now
      require "zip"
      Zip::File.open(zip) do |z|
        manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
        # A has_pages collection whose slug is the exact from_slug of a redirect
        # THIS SAME manifest also restores - page_redirects must be imported
        # before collections so Collection#has_pages_slug_availability sees it
        # and rejects the collision, rather than only checking whatever
        # redirects already happened to exist on the target beforehand.
        manifest["collections"] << {
          "slug" => "home", "name" => "Home Collection", "fields" => [],
          "has_pages" => true, "per_page" => 12, "show_in_sidebar" => false,
          "title_field" => nil, "description_field" => nil, "image_field" => nil
        }
        z.get_output_stream("manifest.json") { |io| io.write(JSON.generate(manifest)) }
      end

      assert_raises(ActiveRecord::RecordInvalid) do
        ActiveCanvas::Importer.new(zip, mode: :replace).run
      end

      # Rolled back entirely: the bad collection was never created, and the
      # original page/redirect this same transaction wiped are back.
      refute ActiveCanvas::Collection.exists?(slug: "home")
      assert_equal "home2", ActiveCanvas::Page.find(page.id).slug
      assert_equal "home2", ActiveCanvas::PageRedirect.find_by(from_slug: "home").page.slug
    end

    test "replace mode also cleans up persisted image variants of removed media" do
      media = build_saved_media(filename: "photo.png", content_type: "image/png")
      blob = media.file.blob

      variant_record = ActiveStorage::VariantRecord.create!(blob: blob, variation_digest: "test-digest")
      variant_blob = ActiveStorage::Blob.create!(
        key: SecureRandom.hex(10), filename: "photo_thumb.png", content_type: "image/png",
        byte_size: 10, checksum: Digest::MD5.base64digest("x"), service_name: ActiveStorage::Blob.service.name
      )
      ActiveStorage::Attachment.create!(record_type: "ActiveStorage::VariantRecord", record_id: variant_record.id, name: "image", blob: variant_blob)

      zip = export_now # only the original media is in the manifest; variants are never exported

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      refute ActiveStorage::VariantRecord.exists?(variant_record.id)
      refute ActiveStorage::Blob.exists?(variant_blob.id)
    end

    test "exported media metadata (width/height) is applied on import" do
      media = build_saved_media(filename: "photo.png", content_type: "image/png")
      media.update!(metadata: { "width" => 800, "height" => 600 })
      zip = export_now

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      new_media = ActiveCanvas::Media.order(:id).last
      assert_equal 800, new_media.metadata["width"]
      assert_equal 600, new_media.metadata["height"]
    end

    test "collection item version change_summary is preserved on import" do
      collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
      item = collection.items.create!
      item.assign_fields("name" => "Ada")
      item.save!
      item.publish!
      item.versions.last.update!(change_summary: "initial publish")
      zip = export_now

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      new_version = ActiveCanvas::Collection.find_by(slug: "team").items.first.versions.first
      assert_equal "initial publish", new_version.change_summary
    end

    test "merging a v1-style manifest (no timestamps) over an existing collection item succeeds" do
      collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
      item = collection.items.create!(slug: "ada")
      item.assign_fields("name" => "Ada")
      item.save!
      zip = export_now
      require "zip"
      Zip::File.open(zip) do |z|
        manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
        manifest["collection_items"].each { |r| r.delete("created_at"); r.delete("updated_at") }
        z.get_output_stream("manifest.json") { |io| io.write(JSON.generate(manifest)) }
      end

      # A real update (not a no-op) so Rails would actually try to write the
      # (previously) explicit nil timestamp to this already-persisted row.
      item.update!(draft_data: { "name" => "Changed locally" })

      assert_nothing_raised do
        ActiveCanvas::Importer.new(zip, mode: :merge).run
      end
      assert_equal "Ada", ActiveCanvas::CollectionItem.find(item.id).draft_data["name"]
    end

    test "pages, versions and form submissions resolve to the right page even when its slug is blank" do
      pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
      page_a = ActiveCanvas::Page.create!(title: "A", page_type: pt, content: "<p>a1</p>")
      page_a.update!(content: "<p>a2</p>")
      ActiveCanvas::FormSubmission.create!(page: page_a, form_key: "a-form", data: {})

      page_b = ActiveCanvas::Page.create!(title: "B", page_type: pt, content: "<p>b1</p>")
      page_b.update!(content: "<p>b2</p>")
      ActiveCanvas::FormSubmission.create!(page: page_b, form_key: "b-form", data: {})

      # Force both back to a blank slug (bypassing the auto-slug-on-save
      # callback, which would otherwise assign one on any second save): the
      # importer must not need a slug to be present to resolve a page.
      page_a.update_column(:slug, nil)
      page_b.update_column(:slug, nil)
      assert_nil page_a.reload.slug
      assert_nil page_b.reload.slug
      zip = export_now

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      new_a = ActiveCanvas::Page.find_by(title: "A")
      new_b = ActiveCanvas::Page.find_by(title: "B")
      assert_equal "<p>a2</p>", new_a.versions.last.content_after
      assert_equal "<p>b2</p>", new_b.versions.last.content_after
      assert_equal "a-form", ActiveCanvas::FormSubmission.find_by(page_id: new_a.id).form_key
      assert_equal "b-form", ActiveCanvas::FormSubmission.find_by(page_id: new_b.id).form_key
    end

    test "a manifest with a non-Hash 'meta' is rejected as InvalidArchive, not a TypeError" do
      seed!
      zip = export_now
      require "zip"
      Zip::File.open(zip) do |z|
        manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
        manifest["meta"] = "not a hash"
        z.get_output_stream("manifest.json") { |io| io.write(JSON.generate(manifest)) }
      end

      assert_raises(ActiveCanvas::Importer::InvalidArchive) do
        ActiveCanvas::Importer.new(zip, mode: :replace).run
      end
    end

    test "a manifest section that isn't an array of objects is rejected as InvalidArchive" do
      seed!
      zip = export_now
      require "zip"
      Zip::File.open(zip) do |z|
        manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
        manifest["pages"] = [ "not an object" ]
        z.get_output_stream("manifest.json") { |io| io.write(JSON.generate(manifest)) }
      end

      assert_raises(ActiveCanvas::Importer::InvalidArchive) do
        ActiveCanvas::Importer.new(zip, mode: :replace).run
      end
    end

    test "replace mode restores collection page options and both templates, linked to the right collection" do
      collection = ActiveCanvas::Collection.create!(
        name: "Team", slug: "team",
        fields: [ { "label" => "Name", "type" => "text" } ],
        has_pages: true, per_page: 5, show_in_sidebar: true
      )
      collection.update!(title_field: collection.fields.first["id"])
      collection.template_pages.find_by(collection_role: "index").update!(content: "<p>custom index</p>")
      collection.template_pages.find_by(collection_role: "show").update!(content: "<p>custom show</p>")
      zip = export_now

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      new_collection = ActiveCanvas::Collection.find_by(slug: "team")
      assert_equal true, new_collection.has_pages
      assert_equal 5, new_collection.per_page
      assert_equal true, new_collection.show_in_sidebar
      assert_equal collection.fields.first["id"], new_collection.title_field

      assert_equal 2, new_collection.template_pages.count, "exactly one index + one show template, no duplicates from ensure_templates!"
      assert_equal "<p>custom index</p>", new_collection.template_pages.find_by(collection_role: "index").content
      assert_equal "<p>custom show</p>", new_collection.template_pages.find_by(collection_role: "show").content
    end

    test "merge mode upserts a collection's template pages by [collection, role] instead of duplicating" do
      collection = ActiveCanvas::Collection.create!(
        name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ], has_pages: true
      )
      collection.template_pages.find_by(collection_role: "index").update!(content: "<p>original index</p>")
      zip = export_now

      # Re-import over the SAME collection (already has_pages: true, so
      # ensure_templates! does not fire again this time) to prove the upsert
      # path itself (not just idempotency-via-callback) is what matches.
      collection.template_pages.find_by(collection_role: "index").update!(content: "<p>locally changed</p>")

      ActiveCanvas::Importer.new(zip, mode: :merge).run

      reloaded = ActiveCanvas::Collection.find_by(slug: "team")
      assert_equal 2, reloaded.template_pages.count
      assert_equal "<p>original index</p>", reloaded.template_pages.find_by(collection_role: "index").content
    end

    test "a replace import restores the index template's exact version history from the manifest" do
      collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [], has_pages: true)
      index_tpl = collection.template_pages.find_by(collection_role: "index")
      index_tpl.update!(content: "<p>v1</p>")
      index_tpl.update!(content: "<p>v2</p>")
      zip = export_now

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      new_tpl = ActiveCanvas::Collection.find_by(slug: "team").template_pages.find_by(collection_role: "index")
      assert_equal 2, new_tpl.versions.count, "exactly the manifest's two versions - no spurious extra from restoring the starter template's content"
      assert_equal [ 1, 2 ], new_tpl.versions.order(:version_number).pluck(:version_number)
      assert_equal "<p>v2</p>", new_tpl.versions.order(:version_number).last.content_after
      assert_equal 2, new_tpl.current_version_number
    end

    test "a merge import appends a new version onto a template's existing history rather than replacing it" do
      collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [], has_pages: true)
      index_tpl = collection.template_pages.find_by(collection_role: "index")
      index_tpl.update!(content: "<p>source v1</p>")
      zip = export_now

      # The target's own local history since that export - independent of what
      # the manifest knows about.
      index_tpl.update!(content: "<p>target v2</p>")
      index_tpl.update!(content: "<p>target v3</p>")
      assert_equal 3, index_tpl.versions.count, "precondition: 3 local versions before merging"

      ActiveCanvas::Importer.new(zip, mode: :merge).run

      reloaded = ActiveCanvas::Collection.find_by(slug: "team").template_pages.find_by(collection_role: "index")
      assert_equal 4, reloaded.versions.count, "merge appends one new version on top of the existing 3 - it never replays or replaces history"
      assert_equal "<p>source v1</p>", reloaded.content
      last_version = reloaded.versions.order(:version_number).last
      assert_equal 4, last_version.version_number
      assert_equal "<p>source v1</p>", last_version.content_after
      assert_equal 4, reloaded.current_version_number
    end

    test "importing a v2 manifest (no collection page options or template pages) still imports the collection with defaults" do
      collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
      zip = export_now
      require "zip"
      Zip::File.open(zip) do |z|
        manifest = JSON.parse(z.find_entry("manifest.json").get_input_stream.read)
        manifest["meta"]["format_version"] = 2
        manifest["collections"].each { |r| %w[has_pages per_page show_in_sidebar title_field description_field image_field].each { |k| r.delete(k) } }
        manifest.delete("collection_template_pages")
        z.get_output_stream("manifest.json") { |io| io.write(JSON.generate(manifest)) }
      end

      assert_nothing_raised { ActiveCanvas::Importer.new(zip, mode: :replace).run }

      new_collection = ActiveCanvas::Collection.find_by(slug: "team")
      assert_equal false, new_collection.has_pages
      assert_equal 12, new_collection.per_page
      assert_equal false, new_collection.show_in_sidebar
      assert_nil new_collection.title_field
      assert_equal 0, new_collection.template_pages.count
    end

    test "a collection item's per-item SEO og_image_media_id is remapped, and dropped with a warning when unmapped" do
      photo = build_saved_media(filename: "og.png", content_type: "image/png")
      svg = with_config(allow_svg_uploads: true) { build_saved_media(filename: "icon.svg", content_type: "image/svg+xml") }
      collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
      item = collection.items.create!
      item.assign_fields("name" => "Ada", "_seo" => { "meta_title" => "Ada", "og_image_media_id" => photo.id.to_s })
      item.save!
      item.publish!

      other = collection.items.create!
      other.assign_fields("name" => "Grace", "_seo" => { "og_image_media_id" => svg.id.to_s })
      other.save!
      other.publish!
      zip = export_now

      summary = ActiveCanvas::Importer.new(zip, mode: :replace).run

      new_photo = ActiveCanvas::Media.find_by(filename: "og.png")
      new_collection = ActiveCanvas::Collection.find_by(slug: "team")
      new_items = new_collection.items.order(:id).to_a
      new_ada, new_grace = new_items

      assert_equal new_photo.id, new_ada.data["_seo"]["og_image_media_id"]
      assert_equal "Ada", new_ada.data["_seo"]["meta_title"]
      refute new_grace.data["_seo"].key?("og_image_media_id"), "unmapped og_image_media_id is dropped, not left dangling"
      assert(summary[:warnings].any? { |w| w.include?("dropped a reference to media id #{svg.id}") })
    end

    test "the total media size cap is configurable via ActiveCanvas.config.import_max_media_bytes" do
      build_saved_media(filename: "a.png")
      zip = export_now

      with_config(import_max_media_bytes: 1) do
        assert_raises(ActiveCanvas::Importer::InvalidArchive) do
          ActiveCanvas::Importer.new(zip, mode: :replace).run
        end
      end
    end
  end
end
