require "test_helper"

class ActiveCanvas::SlugRedirectsTest < ActionDispatch::IntegrationTest
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(
      title: "P", slug: "original", published: true, page_type: @page_type,
      content: "<h1>Hello</h1>"
    )
  end

  test "old slug responds 301 to the current slug" do
    @page.update!(slug: "renamed")

    get "/canvas/original"
    assert_response :moved_permanently
    assert_equal "http://www.example.com/canvas/renamed", response.headers["Location"]
  end

  test "chained renames redirect the original slug straight to the final one" do
    @page.update!(slug: "renamed")
    @page.update!(slug: "final")

    get "/canvas/original"
    assert_response :moved_permanently
    assert_equal "http://www.example.com/canvas/final", response.headers["Location"]
  end

  test "redirect whose target page is unpublished is a 404" do
    @page.update!(slug: "renamed")
    @page.update!(published: false)

    get "/canvas/original"
    assert_response :not_found
  end

  test "a published page shadows a redirect with the same slug" do
    other = ActiveCanvas::Page.create!(title: "Other", slug: "other", published: true, page_type: @page_type)
    # Bypass the callback cleanup to simulate a stale row.
    ActiveCanvas::PageRedirect.create!(from_slug: "original", page: other)

    get "/canvas/original"
    assert_response :success
    assert_includes response.body, "Hello"
  end

  test "unknown slug with no redirect still 404s" do
    get "/canvas/never-existed"
    assert_response :not_found
  end
end
