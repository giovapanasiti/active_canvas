require "test_helper"

# Edge cases around collections with public pages: blank/backfilled item
# slugs, `url`/`seo` field ids, the homepage setting, live-URL changes over
# MCP, the sitemap URL limit and the admin sidebar.
class ActiveCanvas::CollectionPagesHardeningTest < ActionDispatch::IntegrationTest
  def notes_collection(fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    ActiveCanvas::Collection.create!(name: "Notes", slug: "notes", fields: fields)
  end

  def add_item(collection, attrs, publish: true)
    item = collection.items.new
    item.assign_fields(attrs)
    item.save!
    item.publish! if publish
    item
  end

  # --- Item 2: blank slugs --------------------------------------------------

  test "the admin form creates two items with a blank slug in a collection without pages" do
    collection = notes_collection

    2.times do |i|
      post "/canvas/admin/collections/#{collection.id}/items",
        params: { item: { slug: "", data: { name: "Note #{i}" } } }
      assert_response :redirect
    end

    assert_equal [ nil, nil ], collection.items.pluck(:slug)
  end

  # --- Item 3: enabling has_pages on slug-less items -------------------------

  test "enabling has_pages backfills slugs so the sitemap and index links work" do
    collection = notes_collection
    add_item(collection, { "name" => "Ada" })
    add_item(collection, { "name" => "Grace" })

    patch "/canvas/admin/collections/#{collection.id}",
      params: { collection: { name: "Notes", slug: "notes", has_pages: "1", title_field: "name",
                              fields_json: collection.fields.to_json } }
    assert_response :redirect
    assert collection.reload.has_pages?

    get "/canvas/sitemap.xml"
    assert_response :success
    assert_includes response.body, "/canvas/notes/ada"
    assert_includes response.body, "/canvas/notes/grace"

    get "/canvas/notes"
    assert_response :success
    hrefs = Nokogiri::HTML(response.body).css("a").map { |a| a["href"] }
    assert_includes hrefs, "/canvas/notes/ada"
    assert_includes hrefs, "/canvas/notes/grace"
    refute_includes hrefs, "/canvas/notes/"
  end

  test "the sitemap skips a published item with a blank slug" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true, title_field: "name",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    item = add_item(collection, { "name" => "Ada" })
    item.update_column(:slug, nil)

    get "/canvas/sitemap.xml"
    assert_response :success
    assert_includes response.body, "/canvas/team</loc>"
  end

  test "publishing an invalid item from the admin shows a friendly alert" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true, title_field: "name",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    item = add_item(collection, { "name" => "Ada" }, publish: false)
    item.update_column(:slug, nil)

    patch "/canvas/admin/collections/#{collection.id}/items/#{item.id}/publish"
    assert_redirected_to "/canvas/admin/collections/#{collection.id}/items/#{item.id}/edit"
    assert_match(/slug/i, flash[:alert].to_s)
  end

  # --- Item 5: url / seo field ids -------------------------------------------

  test "a collection without pages may keep a url field, with its value intact and editable" do
    collection = notes_collection(fields: [ { "id" => "url", "label" => "URL", "type" => "text" } ])
    assert collection.valid?
    item = add_item(collection, { "url" => "https://example.com/x" })

    assert_equal "https://example.com/x", ActiveCanvas::CollectionSource.new(collection).resolve.first["url"]
    assert_equal "https://example.com/x", ActiveCanvas::CollectionSource.new(collection).row_for(item)["url"]

    get "/canvas/admin/collections/#{collection.id}/items/#{item.id}/edit"
    assert_response :success
    patch "/canvas/admin/collections/#{collection.id}/items/#{item.id}",
      params: { item: { data: { url: "https://example.com/y" } } }
    assert_response :redirect
    assert_equal "https://example.com/y", item.reload.draft_data["url"]
  end

  test "enabling has_pages is refused while a url or seo field exists" do
    %w[url seo].each do |id|
      collection = ActiveCanvas::Collection.create!(name: "C #{id}", slug: "c-#{id}",
        fields: [ { "id" => id, "label" => id.upcase, "type" => "text" } ])

      refute collection.update(has_pages: true)
      assert collection.errors[:fields].any? { |msg| msg.include?(id) && msg.include?("public pages") },
        "expected a clear fields error, got #{collection.errors.full_messages.inspect}"
    end
  end

  test "id, slug, published_at and _seo stay reserved without pages" do
    %w[id slug published_at _seo].each do |id|
      collection = ActiveCanvas::Collection.new(name: "C", slug: "c", fields: [ { "id" => id, "label" => "X", "type" => "text" } ])
      refute collection.valid?, "#{id} should be reserved"
    end
  end

  # --- Item 7: page slug vs collection slug, parameterized --------------------

  test "a page titled Notes can't take the slug of a notes collection with pages" do
    ActiveCanvas::Collection.create!(name: "Notes", slug: "notes", has_pages: true,
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    page = ActiveCanvas::Page.new(title: "Notes", slug: "Notes", page_type: ActiveCanvas::PageType.default)

    refute page.valid?
    assert page.errors[:slug].any?
  end

  # --- Item 8: homepage is a regular page -------------------------------------

  test "Setting.homepage ignores a template page" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true,
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    template = collection.template_pages.first
    template.update_column(:published, true)
    ActiveCanvas::Setting.homepage_page_id = template.id

    assert_nil ActiveCanvas::Setting.homepage
  end

  test "the admin settings form refuses a template page as the homepage" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true,
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    template = collection.template_pages.first

    patch "/canvas/admin/settings", params: { homepage_page_id: template.id }
    assert_nil ActiveCanvas::Setting.homepage_page_id
  end

  test "MCP update_site_settings refuses a template page as the homepage" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true,
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    template = collection.template_pages.first

    _, err = mcp_call(mcp_token, "update_site_settings", { homepage_page_id: template.id })
    assert err, "expected a tool error"
    assert_nil ActiveCanvas::Setting.homepage_page_id
  end

  # --- Item 10: live URL changes over MCP need :publish ------------------------

  test "update_collection changing slug, per_page or title_field of a live collection requires publish" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true, title_field: "name",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" }, { "id" => "alt", "label" => "Alt", "type" => "text" } ])
    add_item(collection, { "name" => "Ada", "alt" => "A" })
    rw = mcp_token(%w[read write])

    { slug: "people", per_page: 5, title_field: "alt" }.each do |key, value|
      _, err = mcp_call(rw, "update_collection", { id: collection.id, key => value })
      assert_match(/publish/i, err.to_s, "#{key} should need the publish scope")
    end
    assert_equal "team", collection.reload.slug

    result, err = mcp_call(mcp_token, "update_collection", { id: collection.id, slug: "people" })
    assert_nil err
    assert_equal "people", result["slug"]

    _, err = mcp_call(rw, "update_collection", { id: collection.id, name: "Crew" })
    assert_nil err
  end

  # --- Item 11: sitemap URL limit counts collection URLs ----------------------

  test "the sitemap URL limit warning counts collection index and item URLs" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true, title_field: "name",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    add_item(collection, { "name" => "Ada" })
    ActiveCanvas::Page.create!(title: "Public", slug: "public-page", published: true, page_type: ActiveCanvas::PageType.default)

    original = ActiveCanvas::SitemapController::URL_LIMIT
    silence_warnings { ActiveCanvas::SitemapController.const_set(:URL_LIMIT, 2) }
    log = capture_log { get "/canvas/sitemap.xml" }
    assert_response :success
    assert_includes log, "sitemap has 3 URLs"
  ensure
    silence_warnings { ActiveCanvas::SitemapController.const_set(:URL_LIMIT, original) } if original
  end

  # --- Item 13: sidebar collections, one query --------------------------------

  test "the admin sidebar loads its collections with one query" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", show_in_sidebar: true,
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])

    queries = collect_sql_queries { get "/canvas/admin/collections/#{collection.id}/items" }
    assert_response :success
    sidebar = queries.select { |sql| sql.include?("show_in_sidebar") }
    assert_equal 1, sidebar.size, sidebar.inspect
  end

  # --- Item 9: admin layout CSS ------------------------------------------------

  test "the admin layout keeps .actions as a flex row" do
    get "/canvas/admin/collections"
    assert_response :success
    assert_match(/\.actions \{\s*display: flex;/, response.body)
  end
end
