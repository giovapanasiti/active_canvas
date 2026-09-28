require "test_helper"

module ActiveCanvas
  class ImporterMediaTest < ActiveSupport::TestCase
    def export_now(**opts)
      path = File.join(Dir.tmpdir, "ac_impm_#{rand(1_000_000)}.zip")
      ActiveCanvas::Exporter.new(**opts).export_to(path)
      path
    end

    test "media bytes restored and data-ac-media-id references remapped" do
      pt = default_page_type
      media = build_saved_media(filename: "logo.png", content_type: "image/png")
      original_bytes = media.file.download
      ActiveCanvas::Page.create!(
        title: "Home", slug: "home", published: true, page_type: pt,
        content: %(<img data-ac-media-id="#{media.id}" src="/stale.png">)
      )
      old_media_id = media.id
      zip = export_now

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      new_media = ActiveCanvas::Media.order(:id).last
      assert_equal original_bytes, new_media.file.download, "bytes byte-identical"
      page = ActiveCanvas::Page.find_by(slug: "home")
      assert_includes page.content, %(data-ac-media-id="#{new_media.id}")
      refute_includes page.content, %(data-ac-media-id="#{old_media_id}") unless new_media.id == old_media_id
    end

    test "merge mode dedups media by checksum (no duplicate)" do
      build_saved_media(filename: "a.png")
      zip = export_now
      before = ActiveCanvas::Media.count

      ActiveCanvas::Importer.new(zip, mode: :merge).run

      assert_equal before, ActiveCanvas::Media.count, "same-checksum media reused, not duplicated"
    end

    test "a collection item's media field and rich_text media refs are remapped on import" do
      media = build_saved_media(filename: "photo.png")
      old_id = media.id
      collection = ActiveCanvas::Collection.create!(
        name: "Team", slug: "team",
        fields: [ { "label" => "Photo", "type" => "media" }, { "label" => "Bio", "type" => "rich_text" } ]
      )
      item = collection.items.create!
      item.assign_fields("photo" => media.id.to_s, "bio" => %(<img data-ac-media-id="#{media.id}">))
      item.save!
      item.publish!
      zip = export_now

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      new_media = ActiveCanvas::Media.order(:id).last
      new_item = ActiveCanvas::Collection.find_by(slug: "team").items.first
      assert_equal new_media.id, new_item.data["photo"]
      assert_includes new_item.data["bio"], %(data-ac-media-id="#{new_media.id}")
      refute_includes new_item.data["bio"], %(data-ac-media-id="#{old_id}") unless new_media.id == old_id
    end

    test "content_components (GrapesJS JSON) stays valid JSON after a media ref is remapped or dropped" do
      pt = default_page_type
      mapped = build_saved_media(filename: "kept.png")
      dropped = with_config(allow_svg_uploads: true) { build_saved_media(filename: "icon.svg", content_type: "image/svg+xml") }

      components = {
        "components" => [
          { "type" => "image", "attributes" => { "data-ac-media-id" => mapped.id.to_s, "id" => "a" } },
          { "type" => "image", "attributes" => { "data-ac-media-id" => dropped.id.to_s, "id" => "b" } }
        ]
      }.to_json
      ActiveCanvas::Page.create!(title: "Home", slug: "home", published: true, page_type: pt, content_components: components)
      zip = export_now

      ActiveCanvas::Importer.new(zip, mode: :replace).run

      page = ActiveCanvas::Page.find_by(slug: "home")
      parsed = JSON.parse(page.content_components) # must not raise - corrupted JSON is the bug this test guards against
      new_mapped = ActiveCanvas::Media.find_by(filename: "kept.png")

      comp_a = parsed["components"].find { |c| c["attributes"]["id"] == "a" }
      comp_b = parsed["components"].find { |c| c["attributes"]["id"] == "b" }
      assert_equal new_mapped.id.to_s, comp_a["attributes"]["data-ac-media-id"]
      refute comp_b["attributes"].key?("data-ac-media-id"), "an unmapped id is dropped from the JSON structurally, not left dangling"
    end

    test "content_components that fails to parse as JSON is left untouched, with a warning" do
      pt = default_page_type
      ActiveCanvas::Page.create!(
        title: "Home", slug: "home", published: true, page_type: pt,
        content_components: "not json {"
      )
      zip = export_now

      summary = ActiveCanvas::Importer.new(zip, mode: :replace).run

      assert_equal "not json {", ActiveCanvas::Page.find_by(slug: "home").content_components
      assert(summary[:warnings].any? { |w| w.include?("content_components could not be parsed") })
    end
  end
end
