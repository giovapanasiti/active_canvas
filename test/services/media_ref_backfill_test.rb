require "test_helper"

module ActiveCanvas
  class MediaRefBackfillTest < ActiveSupport::TestCase
    def legacy_url_for(media)
      Rails.application.routes.url_helpers.rails_blob_path(
        media.file, only_path: true, expires_in: 1.hour
      )
    end

    test "injects data-ac-media-id for legacy blob redirect urls" do
      media = build_saved_media
      page = create_page(content: %(<img src="#{legacy_url_for(media)}">))

      ActiveCanvas::MediaRefBackfill.run

      assert_includes page.reload.content, %(data-ac-media-id="#{media.id}")
    end

    test "recovers media even when the signed id is already expired" do
      media = build_saved_media
      url = legacy_url_for(media)
      page = create_page(content: %(<img src="#{url}">))

      travel 2.hours do
        ActiveCanvas::MediaRefBackfill.run
      end

      assert_includes page.reload.content, %(data-ac-media-id="#{media.id}")
    end

    test "is idempotent" do
      media = build_saved_media
      page = create_page(content: %(<img src="#{legacy_url_for(media)}">))

      ActiveCanvas::MediaRefBackfill.run
      first = page.reload.content
      ActiveCanvas::MediaRefBackfill.run
      assert_equal first, page.reload.content
      assert_equal 1, first.scan(%(data-ac-media-id="#{media.id}")).size
    end

    test "leaves non-active-storage images alone" do
      page = create_page(content: %(<img src="/assets/logo.png">))
      ActiveCanvas::MediaRefBackfill.run
      refute_includes page.reload.content, "data-ac-media-id"
    end
  end
end
