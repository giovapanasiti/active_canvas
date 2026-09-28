require "test_helper"

module ActiveCanvas
  class SeoTest < ActiveSupport::TestCase
    teardown do
      Setting.seo_site_name = ""
      Setting.seo_title_template = nil
      Setting.seo_favicon_media_id = nil
      Setting.seo_robots_txt = ""
      Setting.seo_sitemap_enabled = true
    end

    test "compose_title applies template with site name" do
      Setting.seo_site_name = "Acme"
      assert_equal "Hello | Acme", Seo.compose_title("Hello")
    end

    test "compose_title returns bare title when site name blank" do
      Setting.seo_site_name = ""
      assert_equal "Hello", Seo.compose_title("Hello")
    end

    test "compose_title returns site name when page title blank" do
      Setting.seo_site_name = "Acme"
      assert_equal "Acme", Seo.compose_title(nil)
    end

    test "compose_title does not misinterpret percent signs in title" do
      Setting.seo_site_name = "Acme"
      assert_equal "50% off | Acme", Seo.compose_title("50% off")
    end

    test "favicon_url resolves via media" do
      media = build_saved_media(filename: "favicon.png")
      Setting.seo_favicon_media_id = media.id
      # Signed blob urls embed a per-call expiry token, so compare the stable
      # filename segment rather than the full signed url.
      assert Seo.favicon_url.present?
      assert_includes Seo.favicon_url, "favicon.png"
      assert_equal "image/png", Seo.favicon_content_type
    end

    test "favicon_url is nil when media deleted" do
      Setting.seo_favicon_media_id = 999_999
      assert_nil Seo.favicon_url
    end

    test "robots_txt default lists sitemap when enabled" do
      out = Seo.robots_txt(sitemap_url: "http://x.test/sitemap.xml")
      assert_includes out, "User-agent: *"
      assert_includes out, "Sitemap: http://x.test/sitemap.xml"
    end

    test "robots_txt custom content wins" do
      Setting.seo_robots_txt = "User-agent: *\nDisallow: /admin"
      assert_equal "User-agent: *\nDisallow: /admin", Seo.robots_txt(sitemap_url: "http://x.test/sitemap.xml")
    end

    test "robots_txt omits sitemap line when disabled" do
      Setting.seo_sitemap_enabled = false
      refute_includes Seo.robots_txt(sitemap_url: "http://x.test/sitemap.xml"), "Sitemap:"
    end

    test "sitemap_pages excludes drafts and noindex" do
      pt = default_page_type
      pub = Page.create!(title: "Pub", slug: "pub", published: true, page_type: pt)
      Page.create!(title: "Draft", slug: "draft", published: false, page_type: pt)
      Page.create!(title: "Hidden", slug: "hidden", published: true, meta_robots: "noindex, follow", page_type: pt)

      slugs = Seo.sitemap_pages.map(&:slug)
      assert_includes slugs, "pub"
      refute_includes slugs, "draft"
      refute_includes slugs, "hidden"
      assert_equal [ pub.id ], Seo.sitemap_pages.select { |p| p.slug == "pub" }.map(&:id)
    end
  end
end
