require "test_helper"

class SitemapTest < ActionDispatch::IntegrationTest
  teardown { ActiveCanvas::Setting.seo_sitemap_enabled = true }

  def pt
    ActiveCanvas::PageType.default
  end

  test "lists published pages and excludes drafts" do
    ActiveCanvas::Page.create!(title: "Public", slug: "public-page", published: true, page_type: pt)
    ActiveCanvas::Page.create!(title: "Draft", slug: "draft-page", published: false, page_type: pt)

    get "/canvas/sitemap.xml"
    assert_response :success
    assert_equal "application/xml", @response.media_type
    assert_includes @response.body, "public-page"
    refute_includes @response.body, "draft-page"
    assert_includes @response.body, "<urlset"
  end

  test "excludes noindex pages" do
    ActiveCanvas::Page.create!(title: "No Index", slug: "hidden", published: true,
                               meta_robots: "noindex, follow", page_type: pt)
    get "/canvas/sitemap.xml"
    refute_includes @response.body, "hidden"
  end

  test "returns 404 when sitemap disabled" do
    ActiveCanvas::Setting.seo_sitemap_enabled = false
    get "/canvas/sitemap.xml"
    assert_response :not_found
  end

  test "a published page slugged sitemap.xml cannot shadow the sitemap route" do
    ActiveCanvas::Page.create!(title: "Fake Sitemap", slug: "sitemap.xml", published: true, page_type: pt)

    get "/canvas/sitemap.xml"
    assert_response :success
    assert_equal "application/xml", @response.media_type
    assert_includes @response.body, "<urlset"
  end
end
