require "test_helper"

class SettingsCustomHeadTest < ActionDispatch::IntegrationTest
  teardown { ActiveCanvas::Setting.custom_head_html = "" }

  test "scripts tab renders the custom head html card" do
    get "/canvas/admin/settings", params: { tab: "scripts" }
    assert_response :success
    assert_includes response.body, "Custom &lt;head&gt; HTML"
    assert_includes response.body, "custom-head-html-input"
  end

  test "update_custom_head persists the setting" do
    patch "/canvas/admin/settings/update_custom_head",
          params: { custom_head_html: '<link rel="stylesheet" href="https://example.com/x.css">' },
          as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal '<link rel="stylesheet" href="https://example.com/x.css">',
                 ActiveCanvas::Setting.custom_head_html
  end
end
