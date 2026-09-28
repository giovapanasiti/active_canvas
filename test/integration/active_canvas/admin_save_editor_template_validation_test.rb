require "test_helper"

# save_editor deliberately does NOT run PageContentUpdate's strict Liquid
# validation: the editor autosaves every 60s with no client-side save gate,
# so it must accept half-typed/invalid Liquid without blocking the save. The
# editor's own preview panel calls the separate validate_template endpoint to
# warn authors, tested in admin_validate_template_test.rb.
class ActiveCanvas::AdminSaveEditorTemplateValidationTest < ActionDispatch::IntegrationTest
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "")
  end

  test "save_editor accepts invalid Liquid on a template_enabled page instead of rejecting it" do
    patch "/canvas/admin/pages/#{@page.id}/save_editor",
      params: { page: { content: "{% if %}", template_enabled: "1" } },
      headers: { "Accept" => "application/json" }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    @page.reload
    assert_equal "{% if %}", @page.content
    assert @page.template_enabled?
  end
end
