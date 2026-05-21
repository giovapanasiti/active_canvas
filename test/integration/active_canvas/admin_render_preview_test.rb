require "test_helper"

class ActiveCanvas::AdminRenderPreviewTest < ActionDispatch::IntegrationTest
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "")
  end
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "returns 200 with rendered HTML and chip markers" do
    post "/canvas/admin/pages/#{@page.id}/render_preview",
      params: {
        content: "Hi {{ name }}",
        bindings: { name: { source: "_literal", value: "Liz" } }.to_json
      }
    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body["html"], "data-ac-var=\"name\""
    assert_includes body["html"], "Liz"
    assert_nil body["error"]
  end

  test "returns 422 with line/col on invalid Liquid" do
    post "/canvas/admin/pages/#{@page.id}/render_preview",
      params: { content: "{% for x in %}", bindings: "{}" }
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_kind_of String, body.dig("error", "message")
  end

  test "returns 422 on unknown data source" do
    post "/canvas/admin/pages/#{@page.id}/render_preview",
      params: {
        content: "{{ x }}",
        bindings: { x: { source: "totally_unknown_source" } }.to_json
      }
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body.dig("error", "message").to_s, "totally_unknown_source"
  end
end
