require "test_helper"

class ActiveCanvas::PageRestoreVersionTest < ActiveSupport::TestCase
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "v0", content_css: "c0")
    @page.update!(content: "v1", content_css: "c1")
    @v1 = @page.versions.last
    @page.update!(content: "v2", content_css: "c2")
  end

  test "restoring a version returns the page's content to that version" do
    result = @page.restore_version!(@v1)

    assert result.success?
    assert_equal "v1", @page.reload.content
    assert_equal "c1", @page.content_css
  end

  test "restoring appends a new version rather than deleting later ones" do
    assert_difference -> { @page.versions.count }, 1 do
      @page.restore_version!(@v1)
    end

    assert_equal %w[v1 v2 v1], @page.versions.oldest_first.map(&:content_after)
  end

  # A version saved before the bindings migration has bindings_after == nil (the column
  # didn't exist yet). Restoring it must not wipe out the page's current bindings.
  test "restoring a version with a nil bindings_after keeps the page's current bindings" do
    @page.update_columns(bindings: { "hero" => { "source" => "_literal", "value" => "kept" } })
    @v1.update_columns(bindings_after: nil)

    result = @page.restore_version!(@v1)

    assert result.success?
    assert_equal({ "hero" => { "source" => "_literal", "value" => "kept" } }, @page.reload.bindings)
  end
end
