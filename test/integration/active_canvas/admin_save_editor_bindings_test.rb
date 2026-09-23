require "test_helper"

class ActiveCanvas::AdminSaveEditorBindingsTest < ActionDispatch::IntegrationTest
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "")
  end

  test "save_editor persists bindings and template_enabled" do
    patch "/canvas/admin/pages/#{@page.id}/save_editor",
      params: {
        page: {
          content: "Hi {{ name }}",
          template_enabled: "1",
          bindings: { "name" => { "source" => "_literal", "value" => "Liz" } }.to_json
        }
      },
      headers: { "Accept" => "application/json" }
    assert_response :success
    @page.reload
    assert @page.template_enabled?
    assert_equal "Liz", @page.bindings.dig("name", "value")
  end

  test "save_editor rejects bindings that are not a hash of hashes" do
    [ "[1]", "\"str\"", { "x" => 5 }.to_json, { "x" => { "value" => 1 } }.to_json ].each do |bad|
      patch "/canvas/admin/pages/#{@page.id}/save_editor",
        params: { page: { content: "x", bindings: bad } },
        headers: { "Accept" => "application/json" }
      assert_response :unprocessable_entity, "expected 422 for #{bad}"
      assert_match(/bindings/i, JSON.parse(response.body)["errors"].join)
    end
  end
end
