require "test_helper"

module ActiveCanvas
  class PageTest < ActiveSupport::TestCase
    test "rendered_content resolves media references to fresh urls" do
      media = build_saved_media
      page = create_page(content: %(<img data-ac-media-id="#{media.id}" src="/stale.png">))

      freeze_time do
        rendered = page.rendered_content
        assert_includes rendered, media.url
        refute_includes rendered, "/stale.png"
      end
    end

    test "rendered_content is html_safe" do
      page = create_page(content: "<p>hello</p>")
      assert page.rendered_content.html_safe?
    end
  end
end
