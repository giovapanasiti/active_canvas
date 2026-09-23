require "test_helper"

class ActiveCanvas::DataSourcesTest < ActiveSupport::TestCase
  setup { ActiveCanvas::DataSources.reset_for_testing! }
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "register stores a source by name" do
    ActiveCanvas::DataSources.register(:fixtures) do
      fetch { [ 1, 2, 3 ] }
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

  test "the registry has no _literal pseudo source" do
    refute_includes ActiveCanvas::DataSources.registered_names, :_literal
    assert_not ActiveCanvas::DataSources.registered?(:_literal)
  end

  test "on_error defaults to the configured value at registration time" do
    original = ActiveCanvas.config.template_default_on_error
    ActiveCanvas.config.template_default_on_error = :silent
    ActiveCanvas::DataSources.register(:quiet) { fetch { [] } }
    assert_equal :silent, ActiveCanvas::DataSources.lookup(:quiet).on_error
  ensure
    ActiveCanvas.config.template_default_on_error = original
  end

  test "item_name singularizes the binding name and falls back to item" do
    assert_equal "article", ActiveCanvas::DataSources.item_name("articles")
    assert_equal "member", ActiveCanvas::DataSources.item_name(:members)
    assert_equal "item", ActiveCanvas::DataSources.item_name("team")
    assert_equal "item", ActiveCanvas::DataSources.item_name("")
  end
end
