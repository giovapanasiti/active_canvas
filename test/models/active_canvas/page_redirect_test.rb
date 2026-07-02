require "test_helper"

class ActiveCanvas::PageRedirectTest < ActiveSupport::TestCase
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "Target", slug: "target", page_type: @page_type)
  end

  test "valid with from_slug and page" do
    redirect = ActiveCanvas::PageRedirect.new(from_slug: "old-path", page: @page)
    assert redirect.valid?
  end

  test "requires from_slug" do
    redirect = ActiveCanvas::PageRedirect.new(page: @page)
    assert_not redirect.valid?
  end

  test "requires page" do
    redirect = ActiveCanvas::PageRedirect.new(from_slug: "old-path")
    assert_not redirect.valid?
  end

  test "from_slug is unique" do
    ActiveCanvas::PageRedirect.create!(from_slug: "old-path", page: @page)
    dup = ActiveCanvas::PageRedirect.new(from_slug: "old-path", page: @page)
    assert_not dup.valid?
  end

  test "destroying a page destroys its redirects" do
    ActiveCanvas::PageRedirect.create!(from_slug: "old-path", page: @page)
    @page.destroy
    assert_equal 0, ActiveCanvas::PageRedirect.where(from_slug: "old-path").count
  end
end
