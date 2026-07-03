require "test_helper"

class ActiveCanvas::AdminCollectionsTest < ActionDispatch::IntegrationTest
  def create_collection(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
    ActiveCanvas::Collection.create!(name: name, slug: slug, fields: fields)
  end

  test "index lists collections with field and item counts" do
    collection = create_collection
    item = collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!

    get "/canvas/admin/collections"

    assert_response :success
    assert_includes response.body, "Team"
    assert_includes response.body, "team"          # slug
    assert_select "a[href=?]", "/canvas/admin/collections/new"
  end

  test "index shows an empty state when there are no collections" do
    get "/canvas/admin/collections"
    assert_response :success
    assert_select ".empty-state"
  end
end
