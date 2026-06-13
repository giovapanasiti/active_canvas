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
  end
end
