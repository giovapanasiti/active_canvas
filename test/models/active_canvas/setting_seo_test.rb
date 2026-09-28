require "test_helper"

module ActiveCanvas
  class SettingSeoTest < ActiveSupport::TestCase
    test "site name round-trips and defaults to blank" do
      assert_equal "", Setting.seo_site_name
      Setting.seo_site_name = "My Site"
      assert_equal "My Site", Setting.seo_site_name
    end

    test "title template has a sensible default" do
      assert_equal "%{title} | %{site_name}", Setting.seo_title_template
      Setting.seo_title_template = "%{title} — %{site_name}"
      assert_equal "%{title} — %{site_name}", Setting.seo_title_template
    end

    test "media ids coerce to integer or nil" do
      assert_nil Setting.seo_favicon_media_id
      Setting.seo_favicon_media_id = "42"
      assert_equal 42, Setting.seo_favicon_media_id
      Setting.seo_favicon_media_id = ""
      assert_nil Setting.seo_favicon_media_id
    end

    test "sitemap enabled defaults to true and casts booleans" do
      assert Setting.seo_sitemap_enabled?
      Setting.seo_sitemap_enabled = "0"
      refute Setting.seo_sitemap_enabled?
      Setting.seo_sitemap_enabled = "1"
      assert Setting.seo_sitemap_enabled?
    end
  end
end
