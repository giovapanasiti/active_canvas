require "test_helper"

class ActiveCanvas::AdminDataSourcesCollectionsTest < ActionDispatch::IntegrationTest
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "data_sources endpoint lists collections with their fields" do
    ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Dept", "type" => "select", "options" => %w[eng sales] } ])

    get "/canvas/admin/pages/data_sources.json"
    assert_response :success
    body = JSON.parse(response.body)
    collection = body.find { |entry| entry["name"] == "team" }
    assert_equal "collection", collection["kind"]
    field_ids = collection["fields"].map { |f| f["id"] }
    assert_equal %w[name dept], field_ids
    assert_equal %w[eng sales], collection["fields"].find { |f| f["id"] == "dept" }["options"]
  end
end
