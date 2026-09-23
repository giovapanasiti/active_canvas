require "test_helper"

class ActiveCanvas::AdminValidateTemplateTest < ActionDispatch::IntegrationTest
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "")
  end
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  def validate(content:, bindings:)
    post "/canvas/admin/pages/#{@page.id}/validate_template",
      params: { content: content, bindings: bindings }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    JSON.parse(response.body)
  end

  test "returns ok for a valid template" do
    body = validate(content: "Hi {{ name }}", bindings: { name: { source: "_literal", value: "Liz" } }.to_json)
    assert_response :success
    assert_equal true, body["ok"]
    assert_nil body["error"]
  end

  test "returns 422 with line on invalid Liquid" do
    body = validate(content: "ok\n{% for x in %}", bindings: "{}")
    assert_response :unprocessable_entity
    assert_equal false, body["ok"]
    assert_kind_of String, body.dig("error", "message")
    assert_equal 2, body.dig("error", "line")
  end

  test "returns 422 on an undefined variable, because preview mode is strict" do
    body = validate(content: "{{ nope }}", bindings: "{}")
    assert_response :unprocessable_entity
    assert_match(/nope/, body.dig("error", "message"))
  end

  test "returns 422 on an unknown data source" do
    body = validate(content: "{{ x }}", bindings: { x: { source: "totally_unknown_source" } }.to_json)
    assert_response :unprocessable_entity
    assert_includes body.dig("error", "message"), "totally_unknown_source"
  end

  test "returns 422 on malformed bindings" do
    body = validate(content: "{{ x }}", bindings: "[1]")
    assert_response :unprocessable_entity
    assert_match(/bindings/i, body.dig("error", "message"))
  end

  test "does not render or return HTML" do
    body = validate(content: "<p>{{ name }}</p>", bindings: { name: { source: "_literal", value: "Liz" } }.to_json)
    assert_nil body["html"]
  end

  test "the old render_preview route is gone" do
    post "/canvas/admin/pages/#{@page.id}/render_preview", params: { content: "x" }
    assert_response :not_found
  end
end
