require "test_helper"

class ActiveCanvas::Mcp::DynamicDataToolsTest < ActionDispatch::IntegrationTest
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "")
    @rw = mcp_token(%w[read write])
  end
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "list_data_sources equals DataSourceCatalog.call" do
    result, err = mcp_call(@rw, "list_data_sources")
    assert_nil err
    assert_equal ActiveCanvas::DataSourceCatalog.call.as_json, result
  end

  test "validate_template passes with a literal binding" do
    result, err = mcp_call(@rw, "validate_template", {
      page_id: @page.id, content: "Hi {{ name }}",
      bindings: { name: { source: "_literal", value: "Liz" } }
    })
    assert_nil err
    assert_equal true, result["ok"]
    assert_nil result["error"]
  end

  test "validate_template fails with a line number on invalid Liquid" do
    result, err = mcp_call(@rw, "validate_template", {
      page_id: @page.id, content: "ok\n{% if %}", bindings: {}
    })
    assert_nil err
    assert_equal false, result["ok"]
    assert_kind_of String, result.dig("error", "message")
    assert_equal 2, result.dig("error", "line")
  end

  test "validate_template accepts bindings as a JSON string" do
    result, err = mcp_call(@rw, "validate_template", {
      page_id: @page.id, content: "Hi {{ name }}",
      bindings: { name: { source: "_literal", value: "Liz" } }.to_json
    })
    assert_nil err
    assert_equal true, result["ok"]
  end

  test "validate_template reports an invalid-bindings-shape error as a normal (not-ok) result, not a tool error" do
    result, err = mcp_call(@rw, "validate_template", { page_id: @page.id, content: "x", bindings: "[1]" })
    assert_nil err
    assert_equal false, result["ok"]
    assert_match(/bindings/i, result.dig("error", "message"))
  end

  test "validate_template gives a tool error for bindings that are not valid JSON" do
    _, err = mcp_call(@rw, "validate_template", { page_id: @page.id, content: "x", bindings: "{not json" })
    assert_match(/Invalid bindings JSON/, err)
  end

  test "validate_template gives a not-found tool error for an unknown page" do
    _, err = mcp_call(@rw, "validate_template", { page_id: 999_999, content: "x" })
    assert_match(/not found/i, err)
  end

  test "preview_template_values returns the chip value for a variable" do
    content = %(<span data-ac-var="" data-ac-source="{{ name }}" data-ac-id="c1">{{ name }}</span>)
    result, err = mcp_call(@rw, "preview_template_values", {
      page_id: @page.id, content: content,
      bindings: { name: { source: "_literal", value: "World" } }
    })
    assert_nil err
    assert_equal "World", result.dig("values", "c1")
  end

  test "sample_binding_data returns rows for a collection binding" do
    team = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
    %w[Ada Bob Cy Dee].each { |n| item = team.items.new; item.assign_fields("name" => n); item.save!; item.publish! }

    result, err = mcp_call(@rw, "sample_binding_data", {
      page_id: @page.id, binding: "team",
      bindings: { team: { source: "team", params: { sort_field: "name", sort_dir: "asc" } } }
    })
    assert_nil err
    assert_equal 3, result["rows"].size
    assert_equal "Ada", result["rows"].first["name"]
  end

  test "sample_binding_data respects the limit argument, capped at 20" do
    team = ActiveCanvas::Collection.create!(name: "Team", slug: "team", fields: [ { "label" => "Name", "type" => "text" } ])
    5.times { |i| item = team.items.new; item.assign_fields("name" => "N#{i}"); item.save!; item.publish! }

    result, err = mcp_call(@rw, "sample_binding_data", {
      page_id: @page.id, binding: "team", limit: 2,
      bindings: { team: { source: "team" } }
    })
    assert_nil err
    assert_equal 2, result["rows"].size
  end

  test "sample_binding_data without page_id uses a fresh default-page-type page" do
    result, err = mcp_call(@rw, "sample_binding_data", {
      binding: "greeting", bindings: { greeting: { source: "_literal", value: "unsaved" } }
    })
    assert_nil err
    assert_equal "unsaved", result["rows"]
  end

  test "sample_binding_data gives a tool error for an unknown binding" do
    _, err = mcp_call(@rw, "sample_binding_data", { page_id: @page.id, binding: "ghost", bindings: {} })
    assert_match(/No binding named "ghost"/, err)
  end

  test "validate_template applies a show template's implicit item context" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true, title_field: "name",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    item = collection.items.new(slug: "ada")
    item.assign_fields("name" => "Ada")
    item.save!
    item.publish!
    template = collection.template_pages.find_by!(collection_role: "show")

    result, err = mcp_call(@rw, "validate_template", { page_id: template.id, content: "{{ item.name }} {{ collection.name }}" })
    assert_nil err
    assert_equal true, result["ok"]
  end

  test "preview_template_values resolves a show template's implicit item context" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true, title_field: "name",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    item = collection.items.new(slug: "ada")
    item.assign_fields("name" => "Ada")
    item.save!
    item.publish!
    template = collection.template_pages.find_by!(collection_role: "show")

    content = %(<span data-ac-var="" data-ac-source="{{ item.name }}" data-ac-id="c1">{{ item.name }}</span>)
    result, err = mcp_call(@rw, "preview_template_values", { page_id: template.id, content: content })
    assert_nil err
    assert_equal "Ada", result.dig("values", "c1")
  end

  test "render_page_preview on an index template renders page 1 of published items" do
    collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true, per_page: 1, title_field: "name",
      fields: [ { "id" => "name", "label" => "Name", "type" => "text" } ])
    item1 = collection.items.new(slug: "ada")
    item1.assign_fields("name" => "Ada")
    item1.save!
    item1.publish!
    item2 = collection.items.new(slug: "bob")
    item2.assign_fields("name" => "Bob")
    item2.save!
    item2.publish!
    index_template = collection.template_pages.find_by!(collection_role: "index")

    result, err = mcp_call(@rw, "render_page_preview", { page_id: index_template.id })
    assert_nil err
    assert_includes result["html"], "Bob"
    refute_includes result["html"], "Ada"
  end

  test "render_page_preview returns HTML containing unsaved content and leaves the page unchanged" do
    original_content = @page.content
    result, err = mcp_call(@rw, "render_page_preview", {
      page_id: @page.id, content: "<p>Hi {{ name }}</p>", template_enabled: true,
      bindings: { name: { source: "_literal", value: "Liz" } }
    })
    assert_nil err
    assert_includes result["html"], "<p>Hi Liz</p>"
    assert_equal false, result["truncated"]
    assert_equal original_content, @page.reload.content
  end

  test "render_page_preview gives a tool error when bindings are invalid" do
    _, err = mcp_call(@rw, "render_page_preview", { page_id: @page.id, content: "x", bindings: "[1]" })
    assert_match(/bindings/i, err)
  end

  test "render_page_preview renders a rich_text attachment's URL against the MCP request host, not the bare-renderer placeholder" do
    host! "cms.example.com"

    media = build_saved_media(filename: "pic.png", content_type: "image/png")
    sgid = media.file.blob.attachable_sgid
    team = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "id" => "bio", "label" => "Bio", "type" => "rich_text" } ])
    item = team.items.new
    item.assign_fields("bio" => %(<action-text-attachment sgid="#{sgid}" content-type="image/png" filename="pic.png" width="1" height="1"></action-text-attachment>))
    item.save!
    item.publish!

    page = ActiveCanvas::Page.create!(title: "Team page", page_type: @page_type,
      content: "{% for member in team %}{{ member.bio }}{% endfor %}")

    result, err = mcp_call(@rw, "render_page_preview", {
      page_id: page.id, template_enabled: true,
      bindings: { team: { source: "team" } }
    })

    assert_nil err
    srcs = Nokogiri::HTML(result["html"]).css("img").map { |img| img["src"].to_s }
    assert srcs.any? { |src| src.start_with?("http://cms.example.com/rails/active_storage/") },
      "expected the attachment <img> on the MCP request host, got #{srcs.inspect}"
    refute_includes result["html"], ActiveCanvas::TemplateRenderer::PUBLIC_FALLBACK
    refute_includes result["html"], "example.org"
  end
end
