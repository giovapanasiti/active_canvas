require "test_helper"

class ActiveCanvas::DataSourceCatalogTest < ActiveSupport::TestCase
  setup { ActiveCanvas::DataSources.reset_for_testing! }
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "the literal pseudo source comes first" do
    entries = ActiveCanvas::DataSourceCatalog.call

    first = entries.first
    assert_equal "_literal", first[:name]
    assert_equal "literal", first[:kind]
    assert_equal "Literal", first[:label]
  end

  test "collections are included with their fields" do
    ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Dept", "type" => "select", "options" => %w[eng sales] } ])

    collection = ActiveCanvas::DataSourceCatalog.call.find { |entry| entry[:name] == "team" }

    assert_equal "collection", collection[:kind]
    assert_equal "Team", collection[:label]
    assert_equal "item", collection[:item_name]
    assert_equal true, collection[:list]
    assert_equal %w[name dept], collection[:fields].map { |f| f["id"] }
  end

  test "registered sources appear with label, item_name and list flag" do
    ActiveCanvas::DataSources.register(:latest_articles) do
      param :limit, type: :integer, default: 5, range: 1..50
      fetch { |limit:| [] }
    end

    source = ActiveCanvas::DataSourceCatalog.call.find { |entry| entry[:name].to_s == "latest_articles" }

    assert_equal "source", source[:kind]
    assert_equal "Latest articles", source[:label]
    assert_equal "latest_article", source[:item_name]
    assert_equal true, source[:list]
  end
end
