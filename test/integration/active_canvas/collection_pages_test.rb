require "test_helper"

class ActiveCanvas::CollectionPagesTest < ActionDispatch::IntegrationTest
  def create_collection(slug: "team", per_page: 2, has_pages: true)
    ActiveCanvas::Collection.create!(
      name: "Team", slug: slug, has_pages: has_pages, per_page: per_page,
      fields: [
        { "id" => "name", "label" => "Name", "type" => "text" },
        { "id" => "bio", "label" => "Bio", "type" => "text" }
      ],
      title_field: "name", description_field: "bio"
    )
  end

  def add_item(collection, name, publish:, seo: nil)
    item = collection.items.new
    fields = { "name" => name, "bio" => "#{name}'s bio" }
    fields["_seo"] = seo if seo
    item.assign_fields(fields)
    item.save!
    item.publish! if publish
    item
  end

  test "index page 1 and page 2" do
    collection = create_collection
    5.times { |i| add_item(collection, "Person #{i}", publish: true) }

    get "/canvas/team"
    assert_response :success
    assert_includes response.body, "Person 4"
    assert_includes response.body, "Person 3"

    get "/canvas/team", params: { page: 2 }
    assert_response :success
    assert_includes response.body, "Person 2"
    assert_includes response.body, "Person 1"
  end

  test "?page=0 ?page=abc and ?page=999 are 404" do
    collection = create_collection
    add_item(collection, "Solo", publish: true)

    get "/canvas/team", params: { page: 0 }
    assert_response :not_found

    get "/canvas/team", params: { page: "abc" }
    assert_response :not_found

    get "/canvas/team", params: { page: 999 }
    assert_response :not_found
  end

  test "array or hash ?page params are 404, not a server error" do
    collection = create_collection
    add_item(collection, "Solo", publish: true)

    get "/canvas/team?page[]=1"
    assert_response :not_found

    get "/canvas/team?page[x]=1"
    assert_response :not_found
  end

  test "an empty collection renders" do
    create_collection

    get "/canvas/team"
    assert_response :success
  end

  test "show a published item" do
    collection = create_collection
    item = add_item(collection, "Ada", publish: true)

    get "/canvas/team/#{item.slug}"
    assert_response :success
    assert_includes response.body, "Ada"
  end

  test "a draft item is a 404" do
    collection = create_collection
    item = add_item(collection, "Draft Ada", publish: false)

    get "/canvas/team/#{item.slug}"
    assert_response :not_found
  end

  test "an unknown item is a 404" do
    create_collection

    get "/canvas/team/does-not-exist"
    assert_response :not_found
  end

  test "a collection without has_pages is a 404" do
    collection = create_collection(slug: "hidden", has_pages: false)
    item = add_item(collection, "Ada", publish: true)

    get "/canvas/hidden"
    assert_response :not_found

    get "/canvas/hidden/#{item.slug}"
    assert_response :not_found
  end

  test "a page slug still wins for regular pages" do
    page_type = ActiveCanvas::PageType.create!(name: "Test")
    ActiveCanvas::Page.create!(title: "About", slug: "about", published: true, page_type: page_type, content: "<h1>About us</h1>")
    create_collection

    get "/canvas/about"
    assert_response :success
    assert_includes response.body, "About us"

    get "/canvas/team"
    assert_response :success
  end

  test "/mcp, /sitemap.xml and /robots.txt are unaffected" do
    create_collection

    post "/canvas/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream" }
    refute_equal 404, response.status

    get "/canvas/sitemap.xml"
    assert_response :success

    get "/canvas/robots.txt"
    assert_response :success
  end

  test "head title, description and OG fallbacks" do
    collection = create_collection
    item = add_item(collection, "Ada Lovelace", publish: true)

    get "/canvas/team/#{item.slug}"
    assert_response :success
    assert_includes response.body, "<title>Ada Lovelace</title>"
    assert_includes response.body, %(<meta name="description" content="Ada Lovelace&#39;s bio">)

    get "/canvas/team"
    assert_response :success
    assert_includes response.body, "<title>Team</title>"
  end

  test "_seo overrides the head title/description" do
    collection = create_collection
    item = add_item(collection, "Ada", publish: true,
      seo: { "meta_title" => "Custom title", "meta_description" => "Custom description" })

    get "/canvas/team/#{item.slug}"
    assert_response :success
    assert_includes response.body, "<title>Custom title</title>"
    assert_includes response.body, %(<meta name="description" content="Custom description">)
  end

  test "a script tag in a SEO field is escaped" do
    collection = create_collection
    item = add_item(collection, "Ada", publish: true,
      seo: { "meta_title" => "<script>alert(1)</script>" })

    get "/canvas/team/#{item.slug}"
    assert_response :success
    refute_includes response.body, "<script>alert(1)</script>"
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  test "sitemap entries for a has_pages collection's index and published items" do
    collection = create_collection
    item = add_item(collection, "Ada", publish: true)
    add_item(collection, "Draft Only", publish: false)

    get "/canvas/sitemap.xml"
    assert_response :success
    assert_includes response.body, "/canvas/team</loc>"
    assert_includes response.body, "/canvas/team/#{item.slug}</loc>"
    assert_includes response.body, item.updated_at.utc.xmlschema
  end

  test "Cache-Control: no-store on index and show" do
    collection = create_collection
    item = add_item(collection, "Ada", publish: true)

    get "/canvas/team"
    assert_match(/no-store/, response.headers["Cache-Control"].to_s)

    get "/canvas/team/#{item.slug}"
    assert_match(/no-store/, response.headers["Cache-Control"].to_s)
  end
end
