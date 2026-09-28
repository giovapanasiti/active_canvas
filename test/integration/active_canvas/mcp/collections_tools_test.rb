require "test_helper"

class ActiveCanvas::Mcp::CollectionsToolsTest < ActionDispatch::IntegrationTest
  setup { @rw = mcp_token(%w[read write]) }

  def fields
    [
      { "label" => "Name", "type" => "text", "required" => true },
      { "label" => "Bio", "type" => "textarea" }
    ]
  end

  test "create, list, get (by id and slug), update, delete" do
    created, err = mcp_call(@rw, "create_collection", { name: "Team", fields: fields })
    assert_nil err
    assert_equal "team", created["slug"]
    assert_equal 2, created["fields"].length
    assert_equal 0, created["items_count"]

    listed, = mcp_call(@rw, "list_collections")
    assert_includes listed["items"].map { |i| i["name"] }, "Team"

    by_id, = mcp_call(@rw, "get_collection", { id: created["id"] })
    assert_equal "Team", by_id["name"]

    by_slug, = mcp_call(@rw, "get_collection", { slug: "team" })
    assert_equal created["id"], by_slug["id"]

    updated, = mcp_call(@rw, "update_collection", { id: created["id"], name: "Team 2" })
    assert_equal "Team 2", updated["name"]
    assert_equal 2, updated["fields"].length

    deleted, = mcp_call(@rw, "delete_collection", { id: created["id"] })
    assert_equal true, deleted["deleted"]
  end

  test "create_collection with an invalid field type is a validation tool error" do
    _, err = mcp_call(@rw, "create_collection", { name: "Bad", fields: [ { "label" => "X", "type" => "bogus" } ] })
    assert_match(/Validation failed/, err)
  end

  test "get_collection requires id or slug" do
    _, err = mcp_call(@rw, "get_collection", {})
    refute_nil err
  end

  test "get_collection not found is a tool error" do
    _, err = mcp_call(@rw, "get_collection", { id: 999_999 })
    assert_match(/not found/, err)
  end

  test "delete_collection with a published item requires the publish scope" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: fields)
    item = collection.items.new
    item.assign_fields("name" => "Ada")
    item.save!
    item.publish!

    _, err = mcp_call(@rw, "delete_collection", { id: collection.id })
    assert_match(/published items.*publish/, err)
    assert ActiveCanvas::Collection.exists?(collection.id)

    rwp = mcp_token(%w[read write publish])
    deleted, err2 = mcp_call(rwp, "delete_collection", { id: collection.id })
    assert_nil err2
    assert_equal true, deleted["deleted"]
  end

  test "list_collections' items_count does not run one query per collection" do
    12.times do |i|
      collection = ActiveCanvas::Collection.create!(name: "Coll #{i}", slug: "coll-#{i}", fields: fields)
      2.times do |j|
        item = collection.items.new
        item.assign_fields("name" => "Item #{j}")
        item.save!
      end
    end

    result = nil
    query_count = count_sql_queries { result, = mcp_call(@rw, "list_collections", { limit: 50 }) }

    assert_equal Array.new(12, 2), result["items"].map { |i| i["items_count"] }
    assert_operator query_count, :<=, 6, "expected a flat query count, not one COUNT per collection"
  end

  test "collection write tools are not listed for a read-only token" do
    ro = mcp_token(%w[read])
    names = mcp_tool_names(ro)
    %w[create_collection update_collection delete_collection].each { |n| refute_includes names, n }
  end
end
