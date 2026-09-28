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

    assert_match(/\*\*\*\*/, settings["ai"]["openai_api_key"])

    body = mcp_rpc(@rw, "tools/call", { name: "get_settings", arguments: {} })
    raw_text = body["result"]["content"].first["text"]
    assert_not_includes raw_text, "sk-super-secret-value"
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
