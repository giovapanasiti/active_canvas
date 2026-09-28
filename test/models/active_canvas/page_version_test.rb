require "test_helper"

class ActiveCanvas::PageVersionTest < ActiveSupport::TestCase
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "v0")
    @page.update!(content: "v1")
    @page.update!(content: "v2")
    @page.update!(content: "v3")
  end

  test "previous returns the version right before this one, or nil for the first" do
    v1, v2, v3 = @page.versions.oldest_first.to_a

    assert_nil v1.previous
    assert_equal v1, v2.previous
    assert_equal v2, v3.previous
  end

  test "next returns the version right after this one, or nil for the last" do
    v1, v2, v3 = @page.versions.oldest_first.to_a

    assert_equal v2, v1.next
    assert_equal v3, v2.next
    assert_nil v3.next
  end
end
