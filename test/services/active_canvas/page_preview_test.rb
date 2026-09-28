require "test_helper"

class ActiveCanvas::PagePreviewTest < ActiveSupport::TestCase
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "")
  end
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "the rendered HTML contains the page content and the layout" do
    result = ActiveCanvas::PagePreview.call(@page, content: "<p>Hello preview</p>")

    assert_nil result[:error]
    assert_includes result[:html], "<p>Hello preview</p>"
    assert_includes result[:html], "<!DOCTYPE html>"
  end

  test "renders dynamic content when template_enabled is passed" do
    result = ActiveCanvas::PagePreview.call(
      @page,
      content: "<p>Hi {{ name }}</p>",
      bindings: { "name" => { "source" => "_literal", "value" => "Liz" } },
      template_enabled: true
    )

    assert_nil result[:error]
    assert_includes result[:html], "<p>Hi Liz</p>"
  end

  test "invalid bindings return an error and no HTML" do
    result = ActiveCanvas::PagePreview.call(@page, content: "x", bindings: [ 1 ])

    assert_nil result[:html]
    assert_match(/bindings/i, result[:error][:message])
  end
end
