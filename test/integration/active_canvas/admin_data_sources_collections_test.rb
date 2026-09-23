require "test_helper"

class ActiveCanvas::AdminDataSourcesCollectionsTest < ActionDispatch::IntegrationTest
  setup { ActiveCanvas::DataSources.reset_for_testing! }
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  def entries
    get "/canvas/admin/pages/data_sources.json"
    assert_response :success
    JSON.parse(response.body)
  end

  test "lists the literal pseudo source first" do
    first = entries.first
    assert_equal "_literal", first["name"]
    assert_equal "literal", first["kind"]
    assert_equal "Literal", first["label"]
    assert_equal "string", first.dig("params", "value", "type")
  end

  test "lists collections with their fields and typed params" do
    ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Dept", "type" => "select", "options" => %w[eng sales] } ])

    collection = entries.find { |entry| entry["name"] == "team" }
    assert_equal "collection", collection["kind"]
    assert_equal "Team", collection["label"]
    assert_equal "item", collection["item_name"]
    assert_equal true, collection["list"]
    assert_equal %w[name dept], collection["fields"].map { |f| f["id"] }
    assert_equal %w[eng sales], collection["fields"].find { |f| f["id"] == "dept" }["options"]
    assert_equal [ 1, 500 ], collection.dig("params", "limit", "range")
    assert_equal %w[name dept], collection.dig("params", "sort_field", "allowed")
    assert_equal "Dept", collection.dig("params", "sort_field", "labels", "dept")
  end

  test "lists registered sources with label, item_name, list flag and array ranges" do
    ActiveCanvas::DataSources.register(:latest_articles) do
      param :limit, type: :integer, default: 5, range: 1..50
      fetch { |limit:| [] }
    end
    source = entries.find { |entry| entry["name"] == "latest_articles" }
    assert_equal "source", source["kind"]
    assert_equal "Latest articles", source["label"]
    assert_equal "latest_article", source["item_name"]
    assert_equal true, source["list"]
    assert_equal [ 1, 50 ], source.dig("params", "limit", "range")
  end

  test "every entry follows the contract the Data panel relies on" do
    ActiveCanvas::Collection.create!(name: "Empty", slug: "empty", fields: [])
    ActiveCanvas::DataSources.register(:flag) do
      param :on, type: :boolean, default: false
      returns :one
      fetch { |on:| on }
    end
    entries.each do |entry|
      %w[name kind label item_name list params].each { |key| assert entry.key?(key), "#{entry["name"]} lacks #{key}" }
      entry["params"].each do |pname, spec|
        assert_kind_of Hash, spec, "#{entry["name"]}.#{pname} is not a hash"
        assert spec.key?("type"), "#{entry["name"]}.#{pname} has no type"
      end
    end
  end
end
