require "test_helper"

class ActiveCanvas::PageRedirectLifecycleTest < ActiveSupport::TestCase
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
  end

  test "changing slug of a published page creates a redirect from the old slug" do
    page = ActiveCanvas::Page.create!(title: "P", slug: "first", published: true, page_type: @page_type)
    page.update!(slug: "second")

    redirect = ActiveCanvas::PageRedirect.find_by(from_slug: "first")
    assert_equal page, redirect.page
  end

  test "changing slug of a draft page creates no redirect" do
    page = ActiveCanvas::Page.create!(title: "P", slug: "first", published: false, page_type: @page_type)
    page.update!(slug: "second")

    assert_nil ActiveCanvas::PageRedirect.find_by(from_slug: "first")
  end

  test "chained slug changes keep all old slugs pointing at the page" do
    page = ActiveCanvas::Page.create!(title: "P", slug: "first", published: true, page_type: @page_type)
    page.update!(slug: "second")
    page.update!(slug: "third")

    assert_equal page, ActiveCanvas::PageRedirect.find_by(from_slug: "first").page
    assert_equal page, ActiveCanvas::PageRedirect.find_by(from_slug: "second").page
  end

  test "an existing redirect from a reused slug is repointed to the page that vacates it" do
    other = ActiveCanvas::Page.create!(title: "Other", slug: "old-home", published: true, page_type: @page_type)
    other.update!(slug: "elsewhere") # leaves redirect old-home -> other

    page = ActiveCanvas::Page.create!(title: "P", slug: "old-home", published: true, page_type: @page_type)
    page.update!(slug: "new-home") # vacates old-home again

    assert_equal page, ActiveCanvas::PageRedirect.find_by(from_slug: "old-home").page
  end

  test "a page claiming a slug removes the stale redirect" do
    page = ActiveCanvas::Page.create!(title: "P", slug: "first", published: true, page_type: @page_type)
    page.update!(slug: "second") # leaves redirect first -> page

    ActiveCanvas::Page.create!(title: "New", slug: "first", published: true, page_type: @page_type)

    assert_nil ActiveCanvas::PageRedirect.find_by(from_slug: "first")
  end
end
