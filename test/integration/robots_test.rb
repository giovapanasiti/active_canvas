require "test_helper"

class RobotsTest < ActionDispatch::IntegrationTest
  teardown do
    ActiveCanvas::Setting.seo_robots_txt = ""
    ActiveCanvas::Setting.seo_sitemap_enabled = true
  end

  test "default robots.txt lists the sitemap" do
    get "/canvas/robots.txt"
    assert_response :success
    assert_equal "text/plain", @response.media_type
    assert_includes @response.body, "User-agent: *"
    assert_includes @response.body, "Sitemap: http://www.example.com/canvas/sitemap.xml"
  end

  test "custom robots.txt is returned verbatim" do
    ActiveCanvas::Setting.seo_robots_txt = "User-agent: *\nDisallow: /admin"
    get "/canvas/robots.txt"
    assert_equal "User-agent: *\nDisallow: /admin", @response.body
  end

  test "sitemap line omitted when sitemap disabled" do
    ActiveCanvas::Setting.seo_sitemap_enabled = false
    get "/canvas/robots.txt"
    assert_response :success
    refute_includes @response.body, "Sitemap:"
  end

  test "a published page slugged robots.txt cannot shadow the robots route" do
    pt = ActiveCanvas::PageType.default
    ActiveCanvas::Page.create!(title: "Fake Robots", slug: "robots.txt", published: true, page_type: pt)

    get "/canvas/robots.txt"
    assert_response :success
    assert_equal "text/plain", @response.media_type
    assert_includes @response.body, "User-agent: *"
  end
end
