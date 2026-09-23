require "test_helper"

class ActiveCanvas::AdminEditorPageTest < ActionDispatch::IntegrationTest
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "")
  end

  test "the preview iframe is sandboxed without same-origin access" do
    get "/canvas/admin/pages/#{@page.id}/editor"
    assert_response :success
    assert_select "iframe#preview-modal-iframe[sandbox=?]", "allow-scripts allow-forms"
  end
end
