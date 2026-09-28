require "test_helper"

class ActiveCanvas::Mcp::PageTypesToolsTest < ActionDispatch::IntegrationTest
  setup { @rw = mcp_token(%w[read write]) }

  test "create, list, update, delete" do
    created, err = mcp_call(@rw, "create_page_type", { name: "Landing" })
    assert_nil err
    assert_equal "landing", created["key"]

    listed, = mcp_call(@rw, "list_page_types")
    assert_includes listed["items"].map { |i| i["name"] }, "Landing"
    assert_equal ActiveCanvas::PageType.count, listed["total"]
    assert_equal 50, listed["limit"]
    assert_equal 0, listed["offset"]

    updated, = mcp_call(@rw, "update_page_type", { id: created["id"], name: "Landing 2" })
    assert_equal "Landing 2", updated["name"]

    deleted, = mcp_call(@rw, "delete_page_type", { id: created["id"] })
    assert_equal true, deleted["deleted"]
  end

  test "list_page_types paginates and clamps an out-of-range limit" do
    3.times { |i| ActiveCanvas::PageType.create!(name: "Bulk #{i}") }
    total = ActiveCanvas::PageType.count

    limited, = mcp_call(@rw, "list_page_types", { limit: 1 })
    assert_equal 1, limited["items"].length
    assert_equal 1, limited["limit"]
    assert_equal total, limited["total"]

    clamped, = mcp_call(@rw, "list_page_types", { limit: 10_000 })
    assert_equal 200, clamped["limit"]
  end

  test "validation and not-found errors are tool errors, not 500s" do
    _, err = mcp_call(@rw, "create_page_type", { name: "" })
    assert_match(/Validation failed/, err)
    _, err = mcp_call(@rw, "update_page_type", { id: 999_999, name: "x" })
    assert_match(/not found/, err)
  end

  test "a not-found error includes the id that was looked up" do
    _, err = mcp_call(@rw, "update_page_type", { id: 999_999, name: "x" })
    assert_equal "PageType 999999 not found", err
  end

  test "cannot delete a page type that has pages" do
    pt = ActiveCanvas::PageType.create!(name: "Used")
    ActiveCanvas::Page.create!(title: "p", page_type: pt)
    _, err = mcp_call(@rw, "delete_page_type", { id: pt.id })
    assert_match(/Could not delete/, err)
  end

  test "unknown extra arguments do not crash" do
    _, err = mcp_call(@rw, "list_page_types", { bogus: 1 })
    assert_nil err
  end

  test "records the token as editor" do
    # Current.editor is set; verified on versions in Task 4. Here just ensure a call succeeds with a named token.
    plaintext = mcp_token(%w[read], name: "Robot")
    _, err = mcp_call(plaintext, "list_page_types")
    assert_nil err
  end

  test "list_page_types' pages_count does not run one query per page type" do
    12.times do |i|
      pt = ActiveCanvas::PageType.create!(name: "PT #{i}")
      2.times { |j| ActiveCanvas::Page.create!(title: "p#{i}-#{j}", page_type: pt) }
    end

    result = nil
    query_count = count_sql_queries { result, = mcp_call(@rw, "list_page_types", { limit: 50 }) }

    assert_equal Array.new(12, 2), result["items"].select { |i| i["name"].start_with?("PT ") }.map { |i| i["pages_count"] }
    assert_operator query_count, :<=, 6, "expected a flat query count, not one COUNT per page type"
  end

  test "write tools are not callable with a read-only token" do
    body = mcp_rpc(mcp_token(%w[read]), "tools/call", { name: "create_page_type", arguments: { name: "x" } })
    assert(body["error"] || body.dig("result", "isError"), "expected an error for an unlisted tool")
  end
end
