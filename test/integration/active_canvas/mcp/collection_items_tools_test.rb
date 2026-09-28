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

  test "create_collection_item and update_collection_item round trip seo" do
    created, err = mcp_call(@rw, "create_collection_item", {
      collection_id: @collection.id, slug: "ada", data: { "name" => "Ada" },
      seo: { "meta_title" => "Ada Lovelace", "meta_description" => "A pioneer" }
    })
    assert_nil err
    assert_equal "Ada Lovelace", created["seo"]["meta_title"]
    assert_equal "A pioneer", created["seo"]["meta_description"]
    assert_nil created["seo"]["og_image_media_id"]

    updated, err2 = mcp_call(@rw, "update_collection_item", {
      collection_id: @collection.id, id: created["id"], seo: { "meta_title" => "Ada L." }
    })
    assert_nil err2
    assert_equal "Ada L.", updated["seo"]["meta_title"]
    assert_nil updated["seo"]["meta_description"], "update_collection_item's seo replaces the whole _seo value"
  end

  test "collection_item serializer includes url when the collection has_pages, omits it otherwise" do
    pages_collection = ActiveCanvas::Collection.create!(name: "Docs", slug: "docs", has_pages: true,
      fields: [ { "label" => "Name", "type" => "text" } ])

    with_pages, = mcp_call(@rw, "create_collection_item", { collection_id: pages_collection.id, slug: "getting-started", data: { "name" => "GS" } })
    assert_equal "/canvas/docs/getting-started", with_pages["url"]

    without_pages, = mcp_call(@rw, "create_collection_item", { collection_id: @collection.id, slug: "ada", data: { "name" => "Ada" } })
    refute without_pages.key?("url")
  end

  test "preview_collection_item renders the show template with the item's draft data" do
    pages_collection = ActiveCanvas::Collection.create!(name: "Docs", slug: "docs", has_pages: true, title_field: "name",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    item = pages_collection.items.new(slug: "draft-item")
    item.assign_fields("name" => "Draft Title")
    item.save!

    result, err = mcp_call(@rw, "preview_collection_item", { collection_id: pages_collection.id, id: item.id })
    assert_nil err
    assert_includes result["html"], "Draft Title"
    assert_equal false, result["truncated"]
  end

  test "preview_collection_item does not change the item or leak into the published snapshot" do
    pages_collection = ActiveCanvas::Collection.create!(name: "Docs", slug: "docs", has_pages: true, title_field: "name",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    item = pages_collection.items.new(slug: "draft-item")
    item.assign_fields("name" => "Draft Title")
    item.save!

    mcp_call(@rw, "preview_collection_item", { collection_id: pages_collection.id, id: item.id })

    assert_equal "draft", item.reload.status
    assert_equal({}, item.data)
  end

  test "preview_collection_item is a tool error for an unknown item" do
    _, err = mcp_call(@rw, "preview_collection_item", { collection_id: @collection.id, id: 999_999 })
    assert_match(/not found/i, err)
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
