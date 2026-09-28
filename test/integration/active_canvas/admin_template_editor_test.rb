require "test_helper"

# Task 5 (Spec Part 4 "Editor"): the editor endpoints apply the implicit
# assigns for a collection's template pages, so an author can design against
# real data without saving a binding for it.
class ActiveCanvas::AdminTemplateEditorTest < ActionDispatch::IntegrationTest
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" } ], title_field: "name")
    @collection.update!(has_pages: true)
    @index_page = @collection.template_pages.find_by(collection_role: "index")
    @show_page = @collection.template_pages.find_by(collection_role: "show")
  end
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  def publish(name)
    item = @collection.items.new
    item.assign_fields("name" => name)
    item.save!; item.publish!
    item
  end

  test "the editor page for a template shows the collection label and no slug field" do
    get "/canvas/admin/pages/#{@show_page.id}/editor"
    assert_response :success
    assert_includes response.body, "Collection: Team"
    assert_includes response.body, "item template"
    assert_select "input[name=?]", "page[slug]", count: 0
  end

  test "the editor page for the index template shows the index label" do
    get "/canvas/admin/pages/#{@index_page.id}/editor"
    assert_response :success
    assert_includes response.body, "Collection: Team"
    assert_includes response.body, "index template"
  end

  test "the editor config JSON lists the implicit bindings with field ids" do
    get "/canvas/admin/pages/#{@show_page.id}/editor"
    assert_response :success
    assert_match(/"item":\s*\{"fields":\[.*"id":"name"/, response.body.gsub("\n", ""))
    assert_includes response.body, "\"collection\""
  end

  test "chip_values for a show template resolves {{ item.<field> }} from the first published item" do
    publish("Ada")

    content = %(<span data-ac-var="" data-ac-source="{{ item.name }}" data-ac-id="c1">{{ item.name }}</span>)
    post "/canvas/admin/pages/#{@show_page.id}/chip_values",
      params: { content: content, bindings: "{}" }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Ada", body.dig("values", "c1")
  end

  test "validate_template accepts {{ item.x }} on a show template" do
    post "/canvas/admin/pages/#{@show_page.id}/validate_template",
      params: { content: "<p>{{ item.name }}</p>", bindings: "{}" }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["ok"]
  end

  test "validate_template accepts data-ac-for=\"entry in items\" on an index template" do
    content = %(<div data-ac-for="entry in items">{{ entry.name }}</div>)
    post "/canvas/admin/pages/#{@index_page.id}/validate_template",
      params: { content: content, bindings: "{}" }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["ok"]
  end

  test "preview_iframe for an index template renders page-1 items" do
    publish("Ada")
    publish("Bob")

    content = %(<div data-ac-for="entry in items">{{ entry.name }}</div>)
    post "/canvas/admin/pages/#{@index_page.id}/preview_iframe", params: { content: content }

    assert_response :success
    html = JSON.parse(response.body)["html"]
    assert_includes html, "Ada"
    assert_includes html, "Bob"
  end

  test "save_editor on a template works and creates a version" do
    assert_difference -> { @show_page.versions.count }, 1 do
      patch "/canvas/admin/pages/#{@show_page.id}/save_editor",
        params: { page: { content: "<p>{{ item.name }}</p>" } },
        headers: { "Accept" => "application/json" }
    end

    assert_response :success
    @show_page.reload
    assert_equal "<p>{{ item.name }}</p>", @show_page.content
  end
end
