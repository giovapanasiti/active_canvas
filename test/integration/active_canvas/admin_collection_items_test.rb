require "test_helper"

class ActiveCanvas::AdminCollectionItemsTest < ActionDispatch::IntegrationTest
  setup do
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" }, { "label" => "Active", "type" => "boolean" } ])
  end

  def add_item(name:, active: true, publish: false)
    item = @collection.items.new
    item.assign_fields("name" => name, "active" => active)
    item.save!
    item.publish! if publish
    item
  end

  test "index shows a grid with a column per leading field and a status badge" do
    add_item(name: "Ada", publish: true)
    add_item(name: "Grace", publish: false)

    get "/canvas/admin/collections/#{@collection.id}/items"

    assert_response :success
    assert_includes response.body, "Name"     # header
    assert_includes response.body, "Ada"
    assert_includes response.body, "Grace"
    assert_select ".badge-success"            # published badge
    assert_select ".badge-gray"               # draft badge
  end

  test "index filters by status" do
    add_item(name: "Ada", publish: true)
    add_item(name: "Grace", publish: false)

    get "/canvas/admin/collections/#{@collection.id}/items", params: { status: "published" }

    assert_includes response.body, "Ada"
    refute_includes response.body, "Grace"
  end

  test "index shows an empty state with no items" do
    get "/canvas/admin/collections/#{@collection.id}/items"
    assert_response :success
    assert_select ".empty-state"
  end
end
