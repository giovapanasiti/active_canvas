require "test_helper"

module ActiveCanvas
  class MediaTest < ActiveSupport::TestCase
    test "can attach and persist a file (Active Storage harness works)" do
      media = build_saved_media
      assert media.persisted?
      assert media.file.attached?
    end
  end
end
