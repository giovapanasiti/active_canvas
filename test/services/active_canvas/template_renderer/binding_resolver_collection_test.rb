require "test_helper"

class ActiveCanvas::TemplateRenderer::BindingResolverCollectionTest < ActiveSupport::TestCase
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  setup do
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" } ])
    item = @collection.items.new
    item.assign_fields("name" => "Ada"); item.save!; item.publish!
  end

  test "resolves a collection binding by slug" do
    bindings = { "team" => { "source" => "team", "params" => { "limit" => 5 } } }
    assigns = ActiveCanvas::TemplateRenderer::BindingResolver.new(bindings).resolve
    assert_equal 1, assigns["team"].size
    assert_equal "Ada", assigns["team"].first["name"]
  end

  test "a registered source shadows a same-named collection" do
    ActiveCanvas::DataSources.reset_for_testing!
    ActiveCanvas::DataSources.register(:team) { fetch { [ "from-registry" ] } }
    bindings = { "team" => { "source" => "team", "params" => {} } }
    assigns = ActiveCanvas::TemplateRenderer::BindingResolver.new(bindings).resolve
    assert_equal [ "from-registry" ], assigns["team"]
  end

  test "an unknown non-collection source still raises UnknownSource" do
    bindings = { "x" => { "source" => "does_not_exist", "params" => {} } }
    assert_raises(ActiveCanvas::DataSources::UnknownSource) do
      ActiveCanvas::TemplateRenderer::BindingResolver.new(bindings).resolve
    end
  end

  test "a binding without a source key raises UnknownSource, not NoMethodError" do
    bindings = { "x" => { "params" => {} } }
    assert_raises(ActiveCanvas::DataSources::UnknownSource) do
      ActiveCanvas::TemplateRenderer::BindingResolver.new(bindings).resolve
    end
  end
end
