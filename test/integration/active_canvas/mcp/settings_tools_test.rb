require "test_helper"

class ActiveCanvas::Mcp::SettingsToolsTest < ActionDispatch::IntegrationTest
  setup { @rw = mcp_token(%w[read write publish]) }

  test "get_settings returns site + ai settings with masked keys, never the full key" do
    ActiveCanvas::Setting.ai_openai_api_key = "sk-super-secret-value"

    settings, err = mcp_call(@rw, "get_settings")
    assert_nil err

    assert settings.key?("homepage_page_id")
    assert settings.key?("css_framework")
    assert settings.key?("global_css")
    assert settings.key?("global_js")
    assert settings.key?("custom_head_html")
    assert settings.key?("tailwind_config")
    assert settings.key?("tailwind_available")
    assert settings.key?("ai")
    assert settings.key?("seo")

    assert_match(/\*\*\*\*/, settings["ai"]["openai_api_key"])

    body = mcp_rpc(@rw, "tools/call", { name: "get_settings", arguments: {} })
    raw_text = body["result"]["content"].first["text"]
    assert_not_includes raw_text, "sk-super-secret-value"
  end

  test "get_settings returns the full seo object, including media ids and resolved urls" do
    media = build_saved_media(filename: "favicon.png")
    ActiveCanvas::Setting.seo_site_name = "Acme"
    ActiveCanvas::Setting.seo_title_template = "%{title} — %{site_name}"
    ActiveCanvas::Setting.seo_default_meta_description = "A great site."
    ActiveCanvas::Setting.seo_favicon_media_id = media.id
    ActiveCanvas::Setting.seo_default_og_image_media_id = media.id
    ActiveCanvas::Setting.seo_google_site_verification = "gv"
    ActiveCanvas::Setting.seo_bing_site_verification = "bv"
    ActiveCanvas::Setting.seo_robots_txt = "User-agent: *\nDisallow: /admin"
    ActiveCanvas::Setting.seo_sitemap_enabled = false

    settings, err = mcp_call(@rw, "get_settings")
    assert_nil err
    seo = settings["seo"]

    assert_equal "Acme", seo["site_name"]
    assert_equal "%{title} — %{site_name}", seo["title_template"]
    assert_equal "A great site.", seo["default_meta_description"]
    assert_equal media.id, seo["favicon_media_id"]
    assert_includes seo["favicon_url"], "favicon.png"
    assert_equal media.id, seo["default_og_image_media_id"]
    assert_includes seo["default_og_image_url"], "favicon.png"
    assert_equal "gv", seo["google_site_verification"]
    assert_equal "bv", seo["bing_site_verification"]
    assert_equal "User-agent: *\nDisallow: /admin", seo["robots_txt"]
    refute seo["sitemap_enabled"]
  ensure
    ActiveCanvas::Setting.seo_site_name = ""
    ActiveCanvas::Setting.seo_title_template = nil
    ActiveCanvas::Setting.seo_default_meta_description = ""
    ActiveCanvas::Setting.seo_favicon_media_id = nil
    ActiveCanvas::Setting.seo_default_og_image_media_id = nil
    ActiveCanvas::Setting.seo_google_site_verification = ""
    ActiveCanvas::Setting.seo_bing_site_verification = ""
    ActiveCanvas::Setting.seo_robots_txt = ""
    ActiveCanvas::Setting.seo_sitemap_enabled = true
  end

  test "get_settings is a read-scope tool" do
    plaintext = mcp_token(%w[read])
    _, err = mcp_call(plaintext, "get_settings")
    assert_nil err
  end

  test "update_site_settings sets global_css" do
    updated, err = mcp_call(@rw, "update_site_settings", { global_css: "body { color: red; }" })
    assert_nil err
    assert_equal "body { color: red; }", updated["global_css"]
    ActiveCanvas::Current.reset
    assert_equal "body { color: red; }", ActiveCanvas::Setting.global_css
  end

  test "update_site_settings rejects invalid tailwind_config JSON" do
    _, err = mcp_call(@rw, "update_site_settings", { tailwind_config: "not json" })
    refute_nil err
    assert_match(/tailwind_config/i, err)
  end

  test "update_site_settings rejects a tailwind_config that isn't a JSON object" do
    _, err = mcp_call(@rw, "update_site_settings", { tailwind_config: "[1,2,3]" })
    refute_nil err
    assert_match(/tailwind_config/i, err)
  end

  test "update_site_settings requires homepage_page_id to reference an existing page" do
    _, err = mcp_call(@rw, "update_site_settings", { homepage_page_id: 999_999 })
    refute_nil err
    assert_match(/not found/i, err)
  end

  test "update_site_settings sets homepage_page_id when the page exists" do
    page = create_page(content: "<p>hi</p>")

    updated, err = mcp_call(@rw, "update_site_settings", { homepage_page_id: page.id })
    assert_nil err
    assert_equal page.id, updated["homepage_page_id"]
    ActiveCanvas::Current.reset
    assert_equal page.id, ActiveCanvas::Setting.homepage_page_id
  end

  test "update_site_settings persists seo fields and returns the updated seo object" do
    media = build_saved_media(filename: "favicon.png")

    updated, err = mcp_call(@rw, "update_site_settings", {
      seo_site_name: "Acme",
      seo_title_template: "%{title} — %{site_name}",
      seo_default_meta_description: "A great site.",
      seo_favicon_media_id: media.id,
      seo_google_site_verification: "gv",
      seo_sitemap_enabled: false
    })
    assert_nil err
    seo = updated["seo"]
    assert_equal "Acme", seo["site_name"]
    assert_equal "%{title} — %{site_name}", seo["title_template"]
    assert_equal "A great site.", seo["default_meta_description"]
    assert_equal media.id, seo["favicon_media_id"]
    assert_equal "gv", seo["google_site_verification"]
    refute seo["sitemap_enabled"]

    ActiveCanvas::Current.reset
    assert_equal "Acme", ActiveCanvas::Setting.seo_site_name
    assert_equal media.id, ActiveCanvas::Setting.seo_favicon_media_id
    refute ActiveCanvas::Setting.seo_sitemap_enabled?
  ensure
    ActiveCanvas::Setting.seo_site_name = ""
    ActiveCanvas::Setting.seo_title_template = nil
    ActiveCanvas::Setting.seo_default_meta_description = ""
    ActiveCanvas::Setting.seo_favicon_media_id = nil
    ActiveCanvas::Setting.seo_google_site_verification = ""
    ActiveCanvas::Setting.seo_sitemap_enabled = true
  end

  test "update_site_settings rejects a seo_favicon_media_id that doesn't reference an existing media" do
    _, err = mcp_call(@rw, "update_site_settings", { seo_favicon_media_id: 999_999 })
    refute_nil err
    assert_match(/not found/i, err)
  end

  test "update_site_settings rejects a seo_default_og_image_media_id that doesn't reference an existing media" do
    _, err = mcp_call(@rw, "update_site_settings", { seo_default_og_image_media_id: 999_999 })
    refute_nil err
    assert_match(/not found/i, err)
  end

  test "update_site_settings clears seo_favicon_media_id when given null" do
    media = build_saved_media(filename: "favicon.png")
    ActiveCanvas::Setting.seo_favicon_media_id = media.id

    updated, err = mcp_call(@rw, "update_site_settings", { seo_favicon_media_id: nil })
    assert_nil err
    assert_nil updated["seo"]["favicon_media_id"]

    ActiveCanvas::Current.reset
    assert_nil ActiveCanvas::Setting.seo_favicon_media_id
  ensure
    ActiveCanvas::Setting.seo_favicon_media_id = nil
  end

  test "settings mutation tools require write or publish and are not listed for a plain read token" do
    read_only = mcp_token(%w[read])
    names = mcp_tool_names(read_only)

    assert_not_includes names, "update_site_settings"
    assert_not_includes names, "recompile_tailwind"
  end

  test "recompile_tailwind returns an error when the framework is not tailwind" do
    ActiveCanvas::Setting.css_framework = "bootstrap5"

    _, err = mcp_call(@rw, "recompile_tailwind")
    refute_nil err
  end

  test "recompile_tailwind enqueues pages when tailwind is available and selected" do
    skip "tailwindcss-ruby gem not installed" unless ActiveCanvas::TailwindCompiler.available?

    create_page(content: "<p>hi</p>")
    ActiveCanvas::Setting.css_framework = "tailwind"

    result, err = mcp_call(@rw, "recompile_tailwind")
    assert_nil err
    assert_equal 1, result["enqueued"]
  end
end
