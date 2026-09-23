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

  test "new renders one input per schema field with the right names" do
    get "/canvas/admin/collections/#{@collection.id}/items/new"
    assert_response :success
    assert_select "input[name=?]", "item[data][name]"          # text field
    assert_select "input[type=checkbox][name=?]", "item[data][active]"
  end

  test "create coerces submitted values into draft_data per type" do
    assert_difference "ActiveCanvas::CollectionItem.count", 1 do
      post "/canvas/admin/collections/#{@collection.id}/items",
        params: { item: { slug: "ada", data: { "name" => "Ada", "active" => "1" } } }
    end
    item = ActiveCanvas::CollectionItem.last
    assert_equal "Ada", item.draft_data["name"]
    assert_equal true, item.draft_data["active"]
    assert_equal "draft", item.status
    assert_redirected_to "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
  end

  test "create renders every widget type without error" do
    rich = ActiveCanvas::Collection.create!(name: "Rich", slug: "rich", fields: [
      { "label" => "Body", "type" => "rich_text" },
      { "label" => "Count", "type" => "number" },
      { "label" => "When", "type" => "date" },
      { "label" => "Pick", "type" => "select", "options" => %w[a b] },
      { "label" => "Photo", "type" => "media" }
    ])
    get "/canvas/admin/collections/#{rich.id}/items/new"
    assert_response :success
    assert_select "textarea[name=?]", "item[data][body]"
    assert_select "input[type=number][name=?]", "item[data][count]"
    assert_select "input[type=date][name=?]", "item[data][when]"
    assert_select "select[name=?]", "item[data][pick]"
    assert_select "select[name=?]", "item[data][photo]"
  end

  test "edit pre-fills widgets from draft_data" do
    item = add_item(name: "Ada", active: true)
    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
    assert_response :success
    assert_select "input[name=?][value=?]", "item[data][name]", "Ada"
  end

  test "update merges new values into draft_data non-destructively" do
    item = add_item(name: "Ada", active: true)
    patch "/canvas/admin/collections/#{@collection.id}/items/#{item.id}",
      params: { item: { data: { "name" => "Ada Lovelace" } } }
    item.reload
    assert_equal "Ada Lovelace", item.draft_data["name"]
    assert_equal true, item.draft_data["active"]   # untouched key preserved
    assert_redirected_to "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
  end

  test "create with a scalar item data param does not 500" do
    assert_nothing_raised do
      post "/canvas/admin/collections/#{@collection.id}/items", params: { item: { data: "oops" } }
    end
    assert_not_equal 500, response.status
  end

  test "destroy removes the item" do
    item = add_item(name: "Ada")
    assert_difference "ActiveCanvas::CollectionItem.count", -1 do
      delete "/canvas/admin/collections/#{@collection.id}/items/#{item.id}"
    end
    assert_redirected_to "/canvas/admin/collections/#{@collection.id}/items"
  end

  test "publish copies draft to data, sets published_at and writes a version" do
    item = add_item(name: "Ada", active: true)
    assert_difference "ActiveCanvas::CollectionItemVersion.count", 1 do
      patch "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/publish"
    end
    item.reload
    assert_equal "published", item.status
    assert_equal "Ada", item.data["name"]
    assert_not_nil item.published_at
    assert_redirected_to "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
  end

  test "unpublish returns the item to draft" do
    item = add_item(name: "Ada", publish: true)
    patch "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/unpublish"
    assert_equal "draft", item.reload.status
    assert_redirected_to "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/edit"
  end

  test "history lists versions newest first with snapshot content and no restore control" do
    item = add_item(name: "Ada")
    item.publish!
    item.assign_fields("name" => "Grace Hopper"); item.save!
    item.publish!

    get "/canvas/admin/collections/#{@collection.id}/items/#{item.id}/history"

    assert_response :success
    body = response.body
    assert_operator body.index("Version 2"), :<, body.index("Version 1")   # newest first
    assert_includes body, "Grace Hopper"   # newer snapshot
    assert_includes body, "Ada"            # older snapshot (distinct, not a substring)
    refute_match(/restore/i, body)
  end

  test "publish with a blank required field redirects back with an alert" do
    strict = ActiveCanvas::Collection.create!(name: "Strict", slug: "strict",
      fields: [ { "label" => "Name", "type" => "text", "required" => true } ])
    item = strict.items.create!(draft_data: {})
    patch "/canvas/admin/collections/#{strict.id}/items/#{item.id}/publish"
    assert_redirected_to "/canvas/admin/collections/#{strict.id}/items/#{item.id}/edit"
    assert_match(/Name/, flash[:alert])
    assert_equal "draft", item.reload.status
  end
end
