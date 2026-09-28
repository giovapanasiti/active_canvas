require "test_helper"

class ActiveCanvas::Mcp::CollectionItemsToolsTest < ActionDispatch::IntegrationTest
  setup do
    @rw = mcp_token(%w[read write])
    @rwp = mcp_token(%w[read write publish])
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [
      { "label" => "Name", "type" => "text", "required" => true },
      { "label" => "Active", "type" => "boolean" }
    ])
  end

  test "create, list, get, update, delete" do
    created, err = mcp_call(@rw, "create_collection_item", { collection_id: @collection.id, slug: "ada", data: { "name" => "Ada", "active" => "1" } })
    assert_nil err
    assert_equal "draft", created["status"]
    assert_equal "Ada", created["draft_data"]["name"]
    assert_equal true, created["draft_data"]["active"]

    listed, = mcp_call(@rw, "list_collection_items", { collection_id: @collection.id })
    item = listed["items"].find { |i| i["id"] == created["id"] }
    refute_nil item
    assert_equal "Ada", item["fields"]["name"]

    fetched, = mcp_call(@rw, "get_collection_item", { collection_id: @collection.id, id: created["id"] })
    assert_equal "ada", fetched["slug"]
    # A never-published draft has an empty `data` snapshot, so its draft is always "pending".
    assert_equal true, fetched["pending_changes"]

    updated, = mcp_call(@rw, "update_collection_item", { collection_id: @collection.id, id: created["id"], data: { "name" => "Ada Lovelace" } })
    assert_equal "Ada Lovelace", updated["draft_data"]["name"]

    deleted, = mcp_call(@rw, "delete_collection_item", { collection_id: @collection.id, id: created["id"] })
    assert_equal true, deleted["deleted"]
  end

  test "list_collection_items rejects an invalid status" do
    _, err = mcp_call(@rw, "list_collection_items", { collection_id: @collection.id, status: "bogus" })
    refute_nil err
  end

  test "list_collection_items filters by status" do
    draft_item = @collection.items.create!
    published_item = @collection.items.new
    published_item.assign_fields("name" => "Ada")
    published_item.save!
    published_item.publish!

    listed, = mcp_call(@rw, "list_collection_items", { collection_id: @collection.id, status: "published" })
    ids = listed["items"].map { |i| i["id"] }
    assert_includes ids, published_item.id
    refute_includes ids, draft_item.id
  end

  test "publish_collection_item with a missing required field lists its label" do
    item = @collection.items.create!
    _, err = mcp_call(@rwp, "publish_collection_item", { collection_id: @collection.id, id: item.id })
    assert_match(/Missing required fields: Name/, err)
  end

  test "publish and unpublish a collection item" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!

    published, err = mcp_call(@rwp, "publish_collection_item", { collection_id: @collection.id, id: item.id })
    assert_nil err
    assert_equal "published", published["status"]
    refute_nil published["published_at"]

    unpublished, err2 = mcp_call(@rwp, "unpublish_collection_item", { collection_id: @collection.id, id: item.id })
    assert_nil err2
    assert_equal "draft", unpublished["status"]
  end

  test "unpublish_collection_item is annotated as destructive" do
    tools = mcp_rpc(@rwp, "tools/list")["result"]["tools"]
    tool = tools.find { |t| t["name"] == "unpublish_collection_item" }
    assert_equal true, tool["annotations"]["destructiveHint"]
  end

  test "publish_collection_item and unpublish_collection_item are not listed for read write" do
    names = mcp_tool_names(@rw)
    refute_includes names, "publish_collection_item"
    refute_includes names, "unpublish_collection_item"
  end

  test "updating a published item with read write is a scope error and leaves draft_data unchanged" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!
    item.publish!

    _, err = mcp_call(@rw, "update_collection_item", { collection_id: @collection.id, id: item.id, data: { "name" => "Changed" } })
    assert_match(/publish/, err)
    assert_equal "Ada", item.reload.draft_data["name"]
  end

  test "deleting a published item with read write is a scope error" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!
    item.publish!

    _, err = mcp_call(@rw, "delete_collection_item", { collection_id: @collection.id, id: item.id })
    assert_match(/publish/, err)
    assert ActiveCanvas::CollectionItem.exists?(item.id)
  end

  test "get_collection_item_history returns versions after a publish" do
    item = @collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!
    item.publish!

    history, err = mcp_call(@rw, "get_collection_item_history", { collection_id: @collection.id, id: item.id })
    assert_nil err
    assert_equal 1, history["versions"].length
    assert_equal 1, history["versions"].first["version_number"]
    assert_equal "Ada", history["versions"].first["data"]["name"]
  end
end
