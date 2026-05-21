require "test_helper"

class ActiveCanvas::DataSourcesTest < ActiveSupport::TestCase
  setup { ActiveCanvas::DataSources.reset_for_testing! }
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "register stores a source by name" do
    ActiveCanvas::DataSources.register(:fixtures) do
      fetch { [1, 2, 3] }
    end
    assert_includes ActiveCanvas::DataSources.registered_names, :fixtures
  end

  test "lookup returns the source object" do
    ActiveCanvas::DataSources.register(:fixtures) { fetch { [] } }
    source = ActiveCanvas::DataSources.lookup(:fixtures)
    assert_equal :fixtures, source.name
  end

  test "lookup raises UnknownSource for unregistered names" do
    assert_raises(ActiveCanvas::DataSources::UnknownSource) do
      ActiveCanvas::DataSources.lookup(:nope)
    end
  end

  test "register accepts string or symbol name" do
    ActiveCanvas::DataSources.register("fixtures") { fetch { [] } }
    assert_includes ActiveCanvas::DataSources.registered_names, :fixtures
  end

  test "register after freeze raises RegistryFrozen" do
    ActiveCanvas::DataSources.register(:a) { fetch { [] } }
    ActiveCanvas::DataSources.freeze!
    assert_raises(ActiveCanvas::DataSources::RegistryFrozen) do
      ActiveCanvas::DataSources.register(:b) { fetch { [] } }
    end
  end

  test "_literal pseudo source is registered automatically" do
    assert_includes ActiveCanvas::DataSources.registered_names, :_literal
  end

  test "_literal returns its value param" do
    source = ActiveCanvas::DataSources.lookup(:_literal)
    assert_equal "hello", source.call(value: "hello")
  end
end
