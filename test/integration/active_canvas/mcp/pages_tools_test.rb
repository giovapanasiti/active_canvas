require "test_helper"

class ActiveCanvas::Mcp::PagesToolsTest < ActionDispatch::IntegrationTest
  setup do
    @rwp = mcp_token(%w[read write publish])
    @page_type = ActiveCanvas::PageType.create!(name: "Landing")
  end

  test "create_page creates an unpublished page and applies content" do
    created, err = mcp_call(@rwp, "create_page", {
      title: "About", slug: "about", page_type_key: @page_type.key,
      content: "<p>Hi</p>"
    })
    assert_nil err
    assert_equal false, created["published"]
    assert_equal @page_type.key, created["page_type_key"]
    assert_equal "<p>Hi</p>", ActiveCanvas::Page.find(created["id"]).content
  end

  test "create_page with an unknown page_type_key returns a tool error" do
    _, err = mcp_call(@rwp, "create_page", { title: "About", page_type_key: "nope" })
    assert_equal "Page type 'nope' not found", err
    assert_nil ActiveCanvas::Page.find_by(title: "About")
  end

  test "create_page destroys the page and reports the error when content update fails" do
    _, err = mcp_call(@rwp, "create_page", {
      title: "Bad", page_type_key: @page_type.key,
      content: "{% if %}", template_enabled: true
    })
    assert_match(/line/, err)
    assert_nil ActiveCanvas::Page.find_by(title: "Bad")
  end

  test "get_page returns full content by id or slug" do
    page = create_full_page

    by_id, = mcp_call(@rwp, "get_page", { id: page.id })
    assert_equal page.slug, by_id["slug"]
    assert_equal page.content, by_id["content"]

    by_slug, = mcp_call(@rwp, "get_page", { slug: page.slug })
    assert_equal page.id, by_slug["id"]
  end

  test "get_page with an unknown slug returns not found" do
    _, err = mcp_call(@rwp, "get_page", { slug: "does-not-exist" })
    assert_match(/not found/i, err)
  end

  test "get_page requires id or slug" do
    _, err = mcp_call(@rwp, "get_page", {})
    assert_match(/id or slug/i, err)
  end

  test "list_pages filters by published, page_type_key and query" do
    page_a = create_full_page(title: "Alpha", slug: "alpha", published: true)
    page_b = create_full_page(title: "Beta", slug: "beta", published: false, page_type: @page_type)

    published_only, = mcp_call(@rwp, "list_pages", { published: true })
    ids = published_only["items"].map { |i| i["id"] }
    assert_includes ids, page_a.id
    refute_includes ids, page_b.id

    by_type, = mcp_call(@rwp, "list_pages", { page_type_key: @page_type.key })
    assert_equal [ page_b.id ], by_type["items"].map { |i| i["id"] }

    by_query, = mcp_call(@rwp, "list_pages", { query: "alp" })
    assert_equal [ page_a.id ], by_query["items"].map { |i| i["id"] }
  end

  test "list_pages query matches title/slug case-insensitively" do
    page = create_full_page(title: "Alpha", slug: "alpha")

    by_upper, = mcp_call(@rwp, "list_pages", { query: "ALP" })
    assert_equal [ page.id ], by_upper["items"].map { |i| i["id"] }

    by_mixed, = mcp_call(@rwp, "list_pages", { query: "aLpHa" })
    assert_equal [ page.id ], by_mixed["items"].map { |i| i["id"] }
  end

  test "list_pages does not run one query per page for page_type or homepage_page_id" do
    12.times { |i| create_full_page(title: "Bulk #{i}", slug: "bulk-#{i}") }

    result = nil
    queries = collect_sql_queries { result, = mcp_call(@rwp, "list_pages", { limit: 50 }) }

    assert_equal 12, result["items"].length
    page_type_queries = queries.select { |sql| sql.include?("active_canvas_page_types") }
    setting_queries = queries.select { |sql| sql.include?("active_canvas_settings") }
    assert_operator page_type_queries.length, :<=, 1, "expected page_type to be preloaded, not queried once per page"
    assert_operator setting_queries.length, :<=, 1, "expected homepage_page_id to be read once, not once per page"
  end

  test "list_pages includes public_url and editor_url" do
    page = create_full_page(slug: "url-page", published: true)
    listed, = mcp_call(@rwp, "list_pages", { query: "url-page" })
    item = listed["items"].first
    assert_equal "/canvas/url-page", item["public_url"]
    assert_equal "/canvas/admin/pages/#{page.id}/editor", item["editor_url"]
  end

  test "list_pages pagination: limit returns that many items and total is correct, out-of-range limit is clamped" do
    3.times { |i| create_full_page(title: "Bulk #{i}", slug: "bulk-#{i}") }
    total = ActiveCanvas::Page.count

    limited, = mcp_call(@rwp, "list_pages", { limit: 1 })
    assert_equal 1, limited["items"].length
    assert_equal total, limited["total"]

    clamped, = mcp_call(@rwp, "list_pages", { limit: 10_000 })
    assert_equal 200, clamped["limit"]
  end

  test "update_page updates metadata and SEO fields" do
    page = create_full_page
    updated, = mcp_call(@rwp, "update_page", { id: page.id, title: "New title", meta_title: "Meta!" })
    assert_equal "New title", updated["title"]
    assert_equal "Meta!", updated["meta_title"]
  end

  test "update_page with an unknown page_type_key returns a tool error" do
    page = create_full_page
    _, err = mcp_call(@rwp, "update_page", { id: page.id, page_type_key: "nope" })
    assert_equal "Page type 'nope' not found", err
  end

  test "update_page_content on a static page clears content_components, versions and records the MCP editor" do
    page = create_full_page(content: "<p>old</p>")
    page.update_column(:content_components, "[{}]")

    _, err = mcp_call(@rwp, "update_page_content", { id: page.id, content: "<p>new</p>" })
    assert_nil err

    page.reload
    assert_equal "<p>new</p>", page.content
    assert_nil page.content_components
    version = page.versions.recent.first
    assert_equal "MCP: agent", version.changed_by
  end

  test "update_page_content with invalid Liquid returns a tool error and changes nothing" do
    page = create_full_page(content: "<p>keep</p>", template_enabled: false)
    original_content = page.content
    version_count = page.versions.count

    _, err = mcp_call(@rwp, "update_page_content", { id: page.id, template_enabled: true, content: "{% if %}" })
    assert_match(/line/, err)

    page.reload
    assert_equal original_content, page.content
    assert_equal version_count, page.versions.count
  end

  test "delete_page destroys a page" do
    page = create_full_page
    deleted, = mcp_call(@rwp, "delete_page", { id: page.id })
    assert_equal true, deleted["deleted"]
    assert_nil ActiveCanvas::Page.find_by(id: page.id)
  end

  test "delete_page refuses to delete the homepage" do
    page = create_full_page(published: true)
    ActiveCanvas::Setting.homepage_page_id = page.id
    _, err = mcp_call(@rwp, "delete_page", { id: page.id })
    assert_match(/homepage/i, err)
    assert ActiveCanvas::Page.exists?(page.id)
  end

  test "set_page_published publishes and unpublishes a page" do
    page = create_full_page(published: false)
    published, = mcp_call(@rwp, "set_page_published", { id: page.id, published: true })
    assert_equal true, published["published"]

    unpublished, = mcp_call(@rwp, "set_page_published", { id: page.id, published: false })
    assert_equal false, unpublished["published"]
  end

  test "set_page_published is not listed for a read write token" do
    rw = mcp_token(%w[read write])
    refute_includes mcp_tool_names(rw), "set_page_published"
  end

  test "mutating a published page requires the publish scope and leaves the DB unchanged" do
    rw = mcp_token(%w[read write])
    page = create_full_page(published: true, title: "Orig", content: "<p>orig</p>")

    _, err = mcp_call(rw, "update_page", { id: page.id, title: "Changed" })
    assert_match(/requires the 'publish' scope/, err)
    assert_equal "Orig", page.reload.title

    _, err = mcp_call(rw, "update_page_content", { id: page.id, content: "<p>changed</p>" })
    assert_match(/requires the 'publish' scope/, err)
    assert_equal "<p>orig</p>", page.reload.content

    _, err = mcp_call(rw, "delete_page", { id: page.id })
    assert_match(/requires the 'publish' scope/, err)
    assert ActiveCanvas::Page.exists?(page.id)
  end

  test "a read write token can mutate an unpublished page" do
    rw = mcp_token(%w[read write])
    page = create_full_page(published: false)

    _, err = mcp_call(rw, "update_page", { id: page.id, title: "Changed" })
    assert_nil err

    _, err = mcp_call(rw, "update_page_content", { id: page.id, content: "<p>changed</p>" })
    assert_nil err

    _, err = mcp_call(rw, "delete_page", { id: page.id })
    assert_nil err
  end

  private

  def create_full_page(title: "Page", slug: nil, published: false, page_type: nil, content: "<p>Hi</p>", template_enabled: false)
    ActiveCanvas::Page.create!(
      title: title, slug: slug || title.parameterize, published: published, page_type: page_type || default_page_type,
      content: content, template_enabled: template_enabled
    )
  end
end
