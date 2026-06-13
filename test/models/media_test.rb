require "test_helper"

module ActiveCanvas
  class MediaTest < ActiveSupport::TestCase
    test "can attach and persist a file (Active Storage harness works)" do
      media = build_saved_media
      assert media.persisted?
      assert media.file.attached?
    end

    test "create derives filename from the attached blob when none is given" do
      media = ActiveCanvas::Media.new
      media.file.attach(io: StringIO.new("x"), filename: "derived.png", content_type: "image/png")

      assert media.save, "expected save to succeed, got: #{media.errors.full_messages.to_sentence}"
      assert_equal "derived.png", media.filename
      assert_equal "image/png", media.content_type
    end

    test "images scope includes SVG when allow_svg_uploads is enabled" do
      with_config(allow_svg_uploads: true) do
        svg = build_saved_media(filename: "icon.svg", content_type: "image/svg+xml")
        assert_includes ActiveCanvas::Media.images.to_a, svg
      end
    end

    test "images scope excludes dangerous content types" do
      with_config(allowed_content_types: %w[image/png text/html]) do
        png = build_saved_media(filename: "ok.png", content_type: "image/png")
        # text/html is in DANGEROUS_CONTENT_TYPES — insert it bypassing create-time validation
        dangerous = ActiveCanvas::Media.new(filename: "evil.html", content_type: "text/html", byte_size: 0)
        dangerous.file.attach(io: StringIO.new("<script>"), filename: "evil.html", content_type: "text/html")
        dangerous.save!(validate: false)
        # Even though text/html is listed in allowed_content_types, the scope must not return it
        assert_includes ActiveCanvas::Media.images.to_a, png
        refute_includes ActiveCanvas::Media.images.pluck(:content_type), "text/html"
      end
    end

    test "warns once when public_uploads is true but the service is not public" do
      ActiveCanvas::Media.public_uploads_warned = false
      with_config(public_uploads: true) do
        media = build_saved_media
        output = capture_log { media.url }
        assert_match(/public_uploads is true but/, output)
      end
    ensure
      ActiveCanvas::Media.public_uploads_warned = false
    end

    test "does not warn when public_uploads is false" do
      ActiveCanvas::Media.public_uploads_warned = false
      with_config(public_uploads: false) do
        media = build_saved_media
        output = capture_log { media.url }
        refute_match(/public_uploads is true but/, output)
      end
    end

    test "url for an SVG forces attachment disposition" do
      with_config(allow_svg_uploads: true) do
        svg = build_saved_media(filename: "icon.svg", content_type: "image/svg+xml")
        assert_includes svg.url, "disposition=attachment"
      end
    end

    test "url for a non-SVG image does not force attachment disposition" do
      png = build_saved_media(filename: "ok.png", content_type: "image/png")
      refute_includes png.url, "disposition=attachment"
    end
  end
end
