require "test_helper"

class SettingsSeoTabTest < ActionDispatch::IntegrationTest
  teardown do
    ActiveCanvas::Setting.seo_site_name = ""
    ActiveCanvas::Setting.seo_title_template = nil
    ActiveCanvas::Setting.seo_sitemap_enabled = true
    ActiveCanvas::Setting.seo_favicon_media_id = nil
  end

  test "seo tab renders its form" do
    get "/canvas/admin/settings", params: { tab: "seo" }
    assert_response :success
    assert_includes response.body, "seo-site-name-input"
    assert_includes response.body, "seo-title-template-input"
  end

  test "seo tab renders the current favicon preview" do
    media = build_saved_media(filename: "favicon.png")
    ActiveCanvas::Setting.seo_favicon_media_id = media.id

    get "/canvas/admin/settings", params: { tab: "seo" }
    assert_response :success

    # Signed blob urls embed a per-call expiry token, so match the stable
    # filename segment of the preview <img>'s src rather than the full url.
    preview_tag = response.body[/<img[^>]*ac-media-preview[^>]*>/]
    assert preview_tag, "expected an <img class=\"ac-media-preview\"> tag"
    assert_includes preview_tag, "favicon.png"
    refute_includes preview_tag, "display:none"
    assert_includes response.body, "media_select_preview"
  end

  test "update_seo persists settings" do
    patch "/canvas/admin/settings/update_seo",
          params: {
            seo_site_name: "My Site",
            seo_title_template: "%{title} — %{site_name}",
            seo_default_meta_description: "Desc",
            seo_google_site_verification: "gv",
            seo_sitemap_enabled: "1"
          },
          as: :json

    assert_response :success
    assert JSON.parse(response.body)["success"]
    assert_equal "My Site", ActiveCanvas::Setting.seo_site_name
    assert_equal "%{title} — %{site_name}", ActiveCanvas::Setting.seo_title_template
    assert_equal "gv", ActiveCanvas::Setting.seo_google_site_verification
    assert ActiveCanvas::Setting.seo_sitemap_enabled?
  end

  test "update_seo can disable the sitemap" do
    patch "/canvas/admin/settings/update_seo",
          params: { seo_sitemap_enabled: "0" }, as: :json
    assert_response :success
    refute ActiveCanvas::Setting.seo_sitemap_enabled?
  end
end
