require "test_helper"

class SeoHeadTest < ActionDispatch::IntegrationTest
  def pt
    ActiveCanvas::PageType.default
  end

  teardown do
    ActiveCanvas::Setting.seo_site_name = ""
    ActiveCanvas::Setting.seo_google_site_verification = ""
    ActiveCanvas::Setting.seo_default_meta_description = ""
  end

  test "title uses the composed template" do
    ActiveCanvas::Setting.seo_site_name = "Acme"
    ActiveCanvas::Page.create!(title: "About Us", slug: "about", published: true, page_type: pt)
    get "/canvas/about"
    assert_response :success
    assert_includes @response.body, "<title>About Us | Acme</title>"
  end

  test "google verification meta is rendered when set" do
    ActiveCanvas::Setting.seo_google_site_verification = "abc123"
    ActiveCanvas::Page.create!(title: "Verify", slug: "verify", published: true, page_type: pt)
    get "/canvas/verify"
    assert_includes @response.body, 'name="google-site-verification"'
    assert_includes @response.body, "abc123"
  end

  test "default meta description used when page has none" do
    ActiveCanvas::Setting.seo_default_meta_description = "A great site."
    ActiveCanvas::Page.create!(title: "NoDesc", slug: "nodesc", published: true, page_type: pt)
    get "/canvas/nodesc"
    assert_includes @response.body, 'name="description" content="A great site."'
  end
end
