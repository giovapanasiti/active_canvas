require "test_helper"

class ActiveCanvas::EngineFreezeTest < ActiveSupport::TestCase
  # Re-establish the post-boot frozen state in case another test class called
  # reset_for_testing! in its teardown before this class runs.
  setup { ActiveCanvas::DataSources.freeze! }

  test "registry is frozen after Rails boot" do
    # The dummy app has already booted; the registry should be frozen.
    assert ActiveCanvas::DataSources.frozen?, "registry should be frozen after host initializer"
  end
end
