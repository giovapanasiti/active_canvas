require "test_helper"

class ExportImportRoundTripTest < ActionDispatch::IntegrationTest
  test "export then replace-import reproduces the same dataset" do
    pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
    media = build_saved_media(filename: "logo.png")
    ActiveCanvas::Page.create!(title: "Home", slug: "home", published: true, page_type: pt,
                               content: %(<img data-ac-media-id="#{media.id}">))
    ActiveCanvas::Partial.create!(partial_type: "header", name: "H", content: "<header/>")
    ActiveCanvas::Setting.global_css = "body{}"
    bytes = media.file.download

    path = File.join(Dir.tmpdir, "ac_rt_#{rand(1_000_000)}.zip")
    ActiveCanvas::Exporter.new.export_to(path)

    # Wipe everything by importing in replace mode into the same DB
    ActiveCanvas::Importer.new(path, mode: :replace).run

    assert_equal %w[home], ActiveCanvas::Page.pluck(:slug)
    assert_equal "Default", ActiveCanvas::PageType.find_by(key: "default").name
    assert_equal "H", ActiveCanvas::Partial.find_by(partial_type: "header").name
    assert_equal "body{}", ActiveCanvas::Setting.global_css
    new_media = ActiveCanvas::Media.order(:id).last
    assert_equal bytes, new_media.file.download
    assert_includes ActiveCanvas::Page.find_by(slug: "home").content, %(data-ac-media-id="#{new_media.id}")
  end

  # A full clone: every model added since the original spec (collections/items/
  # versions, redirects, form submissions, SEO + homepage settings) is seeded,
  # exported, then replace-imported into the SAME database, and asserted to be
  # byte-for-byte / id-for-id equivalent (accounting for ids that necessarily
  # shift, which are proven remapped instead). ApiTokens are proven untouched.
  test "a full instance clone (replace mode) restores every model, with ids correctly remapped" do
    pt = ActiveCanvas::PageType.create!(key: "default", name: "Default")
    favicon = build_saved_media(filename: "favicon.png", content_type: "image/png")
    photo = build_saved_media(filename: "photo.png", content_type: "image/png")
    favicon_bytes = favicon.file.download
    photo_bytes = photo.file.download

    home = ActiveCanvas::Page.create!(
      title: "Home", slug: "home", published: true, page_type: pt, template_enabled: true,
      bindings: { "team" => { "source" => "team" } },
      content: %(<img data-ac-media-id="#{favicon.id}">)
    )
    # Single update so it creates exactly one PageVersion, capturing both a
    # content change AND a bindings change (bindings_before/after) together.
    home.update!(
      content: %(<img data-ac-media-id="#{favicon.id}"><p>v2</p>),
      bindings: { "team" => { "source" => "team" }, "extra" => { "source" => "team" } }
    )
    original_version = home.versions.last
    home.update!(slug: "home-page") # leaves a PageRedirect "home" -> home-page
    submission = ActiveCanvas::FormSubmission.create!(page: home, form_key: "contact", data: { "email" => "a@b.c" })
    original_submission_created_at = submission.created_at

    ActiveCanvas::Partial.create!(partial_type: "header", name: "H",
      content: %(<img data-ac-media-id="#{favicon.id}">))

    collection = ActiveCanvas::Collection.create!(
      name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Photo", "type" => "media" } ]
    )
    item = collection.items.create!
    item.assign_fields("name" => "Ada", "photo" => photo.id.to_s)
    item.save!
    item.publish!
    item.assign_fields("name" => "Ada Lovelace")
    item.save!
    item.publish! # two versions now

    ActiveCanvas::AiModel.create!(model_id: "gpt-x", provider: "openai", name: "GPT X")

    ActiveCanvas::Setting.global_css = "body{color:blue}"
    ActiveCanvas::Setting.homepage_page_id = home.id
    ActiveCanvas::Setting.seo_favicon_media_id = favicon.id
    ActiveCanvas::Setting.seo_default_og_image_media_id = photo.id
    ActiveCanvas::Setting.ai_openai_api_key = "sk-secret"

    token, plaintext = ActiveCanvas::ApiToken.issue!(name: "agent", scopes: %w[read])

    path = File.join(Dir.tmpdir, "ac_rt_full_#{rand(1_000_000)}.zip")
    ActiveCanvas::Exporter.new.export_to(path)

    ActiveCanvas::Importer.new(path, mode: :replace).run

    # Pages: content, template flag, bindings, media ref remapped
    new_home = ActiveCanvas::Page.find_by(slug: "home-page")
    new_favicon = ActiveCanvas::Media.find_by(filename: "favicon.png")
    new_photo = ActiveCanvas::Media.find_by(filename: "photo.png")
    assert new_home.template_enabled?
    assert_equal({ "team" => { "source" => "team" }, "extra" => { "source" => "team" } }, new_home.bindings)
    assert_includes new_home.content, %(data-ac-media-id="#{new_favicon.id}")
    assert_equal 1, new_home.versions.count
    assert_equal favicon_bytes, new_favicon.file.download
    assert_equal photo_bytes, new_photo.file.download

    # Page version: bindings_before/bindings_after and created_at preserved
    new_version = new_home.versions.last
    assert_equal original_version.bindings_before, new_version.bindings_before
    assert_equal original_version.bindings_after, new_version.bindings_after
    assert_equal original_version.created_at.to_i, new_version.created_at.to_i

    # Partial content ref remapped
    assert_includes ActiveCanvas::Partial.find_by(partial_type: "header").content, %(data-ac-media-id="#{new_favicon.id}")

    # Redirect follows the page to its new id
    assert_equal "home-page", ActiveCanvas::PageRedirect.find_by(from_slug: "home").page.slug

    # Form submission restored against the right page, with its original created_at
    new_submission = ActiveCanvas::FormSubmission.first
    assert_equal "contact", new_submission.form_key
    assert_equal new_home.id, new_submission.page_id
    assert_equal original_submission_created_at.to_i, new_submission.created_at.to_i

    # Collection + items + item media field remapped + full version history
    new_collection = ActiveCanvas::Collection.find_by(slug: "team")
    new_item = new_collection.items.first
    assert_equal "Ada Lovelace", new_item.data["name"]
    assert_equal new_photo.id, new_item.data["photo"]
    assert_equal 2, new_item.versions.count

    # AI model restored
    assert ActiveCanvas::AiModel.exists?(model_id: "gpt-x")

    # Settings: plain, secret (decrypted/re-encrypted), and both id-referencing kinds remapped
    assert_equal "body{color:blue}", ActiveCanvas::Setting.global_css
    assert_equal "sk-secret", ActiveCanvas::Setting.ai_openai_api_key
    assert_equal new_home.id, ActiveCanvas::Setting.homepage_page_id
    assert_equal new_favicon.id, ActiveCanvas::Setting.seo_favicon_media_id
    assert_equal new_photo.id, ActiveCanvas::Setting.seo_default_og_image_media_id

    # ApiTokens are never part of the portable dataset; replace does not touch them
    assert ActiveCanvas::ApiToken.exists?(token.id)
    assert_equal token, ActiveCanvas::ApiToken.authenticate(plaintext)

    # No leftovers from the pre-import state (exact clone, not an accumulation)
    assert_equal 1, ActiveCanvas::Page.count
    assert_equal 1, ActiveCanvas::Partial.count
    assert_equal 1, ActiveCanvas::Collection.count
    assert_equal 1, ActiveCanvas::CollectionItem.count
    assert_equal 2, ActiveCanvas::Media.count
  end
end
