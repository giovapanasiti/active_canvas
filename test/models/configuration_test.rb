require "test_helper"

module ActiveCanvas
  class ConfigurationTest < ActiveSupport::TestCase
    test "effective_allowed_content_types de-duplicates SVG" do
      config = ActiveCanvas::Configuration.new
      config.allowed_content_types = %w[image/png image/svg+xml]
      config.allow_svg_uploads = true

      types = config.effective_allowed_content_types
      assert_equal types.uniq, types, "expected no duplicate content types"
      assert_equal 1, types.count("image/svg+xml")
    end
  end
end
