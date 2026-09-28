require "test_helper"
require "zip"

module ActiveCanvas
  class ExporterTest < ActiveSupport::TestCase
    def read_manifest(zip_path)
      Zip::File.open(zip_path) do |zip|
        JSON.parse(zip.find_entry("manifest.json").get_input_stream.read)
      end
    end

    def export_to_tmp(**opts)
      path = File.join(Dir.tmpdir, "ac_export_#{SecureRandom.hex(8)}.zip")
      ActiveCanvas::Exporter.new(**opts).export_to(path)
      path
    end

    test "FORMAT_VERSION is 3" do
      assert_equal 3, ActiveCanvas::Exporter::FORMAT_VERSION
    end

    test "manifest exports collection page options and template pages by collection slug + role, separately from regular pages" do
      collection = ActiveCanvas::Collection.create!(
        name: "Team", slug: "team",
        fields: [ { "label" => "Name", "type" => "text" } ],
        has_pages: true, per_page: 5, show_in_sidebar: true
      )
      collection.update!(title_field: collection.fields.first["id"])

      manifest = read_manifest(export_to_tmp)

      row = manifest["collections"].find { |h| h["slug"] == "team" }
      assert_equal true, row["has_pages"]
      assert_equal 5, row["per_page"]
      assert_equal true, row["show_in_sidebar"]
      assert_equal collection.fields.first["id"], row["title_field"]

      refute(manifest["pages"].any? { |h| h["slug"].nil? }, "template pages are not exported as regular pages")

      index_row = manifest["collection_template_pages"].find { |h| h["collection_role"] == "index" }
      show_row = manifest["collection_template_pages"].find { |h| h["collection_role"] == "show" }
      assert_equal "team", index_row["collection_slug"]
      assert_equal "team", show_row["collection_slug"]
      assert index_row["content"].present?
    end

    test "manifest includes meta, settings, page_types, pages, partials, media" do
      pt = default_page_type
      ActiveCanvas::Page.create!(title: "Home", slug: "home", published: true, page_type: pt, content: "<p>hi</p>")
      ActiveCanvas::Setting.global_css = "body{color:red}"
      media = build_saved_media

      manifest = read_manifest(export_to_tmp)

      assert_equal ActiveCanvas::Exporter::FORMAT_VERSION, manifest.dig("meta", "format_version")
      assert_includes manifest["page_types"].map { |h| h["key"] }, "default"
      assert(manifest["pages"].any? { |h| h["slug"] == "home" && h["page_type_key"] == "default" })
      assert(manifest["settings"].any? { |h| h["key"] == "global_css" && h["value"] == "body{color:red}" })
      assert(manifest["media"].any? { |h| h["source_id"] == media.id && h["checksum"].present? })
    end

    test "media bytes are written into the zip and match the original" do
      media = build_saved_media(filename: "logo.png", content_type: "image/png")
      original = media.file.download

      path = export_to_tmp
      entry = read_manifest(path)["media"].find { |h| h["source_id"] == media.id }
      bytes = Zip::File.open(path) { |zip| zip.find_entry(entry["file"]).get_input_stream.read }

      assert_equal original, bytes
    end

    test "secrets are excluded when include_secrets is false" do
      ActiveCanvas::Setting.set("ai_openai_api_key", "sk-secret")
      manifest = read_manifest(export_to_tmp(include_secrets: false))
      refute(manifest["settings"].any? { |h| h["key"] == "ai_openai_api_key" })
    end

    test "secrets are included (decrypted) when include_secrets is true" do
      ActiveCanvas::Setting.set("ai_openai_api_key", "sk-secret")
      manifest = read_manifest(export_to_tmp(include_secrets: true))
      assert(manifest["settings"].any? { |h| h["key"] == "ai_openai_api_key" && h["value"] == "sk-secret" })
    end

    test "page_versions and ai_models omitted when toggled off" do
      manifest = read_manifest(export_to_tmp(include_versions: false, include_ai_models: false))
      refute manifest.key?("page_versions")
      refute manifest.key?("ai_models")
    end

    test "collection_item_versions omitted when include_versions is false" do
      collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
      item = collection.items.create!
      item.assign_fields("name" => "Ada")
      item.save!
      item.publish!

      manifest = read_manifest(export_to_tmp(include_versions: false))
      refute manifest.key?("collection_item_versions")
      assert manifest.key?("collection_items")
    end

    test "manifest includes page_type_enabled/bindings, redirects, form submissions, collections and items" do
      pt = default_page_type
      media = build_saved_media(filename: "logo.png")
      page = ActiveCanvas::Page.create!(
        title: "Home", slug: "home", published: true, page_type: pt,
        content: %(<img data-ac-media-id="#{media.id}">), bindings: { "list" => { "source" => "team" } },
        template_enabled: true
      )
      page.update!(slug: "home2") # generates a PageRedirect from "home" -> this page
      ActiveCanvas::FormSubmission.create!(page: page, form_key: "contact", data: { "email" => "a@b.c" })

      collection = ActiveCanvas::Collection.create!(
        name: "Team", slug: "team",
        fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Photo", "type" => "media" } ]
      )
      item = collection.items.create!
      item.assign_fields("name" => "Ada", "photo" => media.id.to_s)
      item.save!
      item.publish!

      manifest = read_manifest(export_to_tmp)

      home_row = manifest["pages"].find { |h| h["slug"] == "home2" }
      assert_equal true, home_row["template_enabled"]
      assert_equal({ "list" => { "source" => "team" } }, home_row["bindings"])

      assert(manifest["page_redirects"].any? { |h| h["from_slug"] == "home" && h["page_slug"] == "home2" })
      assert(manifest["form_submissions"].any? { |h| h["form_key"] == "contact" && h["page_slug"] == "home2" })

      assert(manifest["collections"].any? { |h| h["slug"] == "team" && h["name"] == "Team" })
      item_row = manifest["collection_items"].find { |h| h["collection_slug"] == "team" }
      assert_equal "published", item_row["status"]
      assert_equal media.id, item_row["data"]["photo"]
      assert_equal item.id, item_row["source_id"]

      version_row = manifest["collection_item_versions"].find { |h| h["item_source_id"] == item.id }
      assert_equal 1, version_row["version_number"]
    end

    test "homepage_page_slug resolves the homepage setting to a natural key, and media id settings pass through raw" do
      pt = default_page_type
      page = ActiveCanvas::Page.create!(title: "Home", slug: "home", published: true, page_type: pt)
      media = build_saved_media
      ActiveCanvas::Setting.homepage_page_id = page.id
      ActiveCanvas::Setting.seo_favicon_media_id = media.id

      manifest = read_manifest(export_to_tmp)

      assert_equal "home", manifest["homepage_page_slug"]
      refute(manifest["settings"].any? { |h| h["key"] == "homepage_page_id" }, "raw homepage id is not exported as a generic setting")
      assert(manifest["settings"].any? { |h| h["key"] == "seo_favicon_media_id" && h["value"] == media.id })
    end

    test "ApiTokens are never exported" do
      ActiveCanvas::ApiToken.issue!(name: "agent", scopes: %w[read])
      manifest = read_manifest(export_to_tmp)
      refute manifest.key?("api_tokens")
    end

    test "meta records the include flags used for this export" do
      manifest = read_manifest(export_to_tmp(include_versions: false, include_ai_models: false, include_secrets: false))
      assert_equal false, manifest.dig("meta", "include_versions")
      assert_equal false, manifest.dig("meta", "include_ai_models")
      assert_equal false, manifest.dig("meta", "include_secrets")

      manifest2 = read_manifest(export_to_tmp)
      assert_equal true, manifest2.dig("meta", "include_versions")
      assert_equal true, manifest2.dig("meta", "include_ai_models")
      assert_equal true, manifest2.dig("meta", "include_secrets")
    end

    test "page versions export bindings_before/bindings_after and timestamps" do
      pt = default_page_type
      page = ActiveCanvas::Page.create!(title: "Home", page_type: pt, bindings: { "a" => { "source" => "team" } })
      page.update!(bindings: { "b" => { "source" => "team" } })
      version = page.versions.last

      manifest = read_manifest(export_to_tmp)
      row = manifest["page_versions"].find { |h| h["version_number"] == version.version_number }
      assert_equal({ "a" => { "source" => "team" } }, row["bindings_before"])
      assert_equal({ "b" => { "source" => "team" } }, row["bindings_after"])
      assert row["created_at"].present?
    end

    test "form submissions, page versions, item versions, media and collection items export their timestamps" do
      pt = default_page_type
      page = ActiveCanvas::Page.create!(title: "Home", slug: "home", page_type: pt)
      page.update!(content: "<p>v2</p>")
      submission = ActiveCanvas::FormSubmission.create!(page: page, form_key: "contact", data: {})
      media = build_saved_media

      collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
      item = collection.items.create!
      item.assign_fields("name" => "Ada")
      item.save!
      item.publish!

      manifest = read_manifest(export_to_tmp)

      sub_row = manifest["form_submissions"].find { |h| h["form_key"] == "contact" }
      assert_equal submission.created_at.to_i, Time.iso8601(sub_row["created_at"]).to_i

      version_row = manifest["page_versions"].find { |h| h["page_slug"] == "home" }
      assert version_row["created_at"].present?

      media_row = manifest["media"].find { |h| h["source_id"] == media.id }
      assert_equal media.created_at.to_i, Time.iso8601(media_row["created_at"]).to_i

      item_row = manifest["collection_items"].find { |h| h["collection_slug"] == "team" }
      assert item_row["created_at"].present?

      item_version_row = manifest["collection_item_versions"].find { |h| h["item_source_id"] == item.id }
      assert item_version_row["created_at"].present?
      assert item_version_row.key?("change_summary")
    end
  end
end
