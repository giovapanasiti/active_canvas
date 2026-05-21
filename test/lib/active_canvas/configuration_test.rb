require "test_helper"

class ActiveCanvas::ConfigurationDynamicContentTest < ActiveSupport::TestCase
  test "dynamic content defaults" do
    config = ActiveCanvas::Configuration.new
    assert_equal 1_000_000, config.template_render_length_limit
    assert_equal 100_000,   config.template_render_score_limit
    assert_equal 10_000,    config.template_assign_score_limit
    assert_equal :raise,    config.template_default_on_error
  end

  test "dynamic content settings are writable" do
    config = ActiveCanvas::Configuration.new
    config.template_render_length_limit = 500_000
    assert_equal 500_000, config.template_render_length_limit
  end
end
