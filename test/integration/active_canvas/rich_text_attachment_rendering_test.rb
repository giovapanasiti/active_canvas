require "test_helper"

# A rich_text field holding a real Active Storage blob attachment must render
# to an <img> whose src is an absolute URL on the current request's host, in
# every place a collection item is rendered: the Active Storage routes live in
# the host app, not in the engine, so the attachment partial has to be
# rendered with the host app's routes.
class ActiveCanvas::RichTextAttachmentRenderingTest < ActionDispatch::IntegrationTest
  setup do
    host! "cms.example.com"
    media = build_saved_media(filename: "pic.png", content_type: "image/png")
    @sgid = media.file.blob.attachable_sgid
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team", has_pages: true,
      fields: [
        { "id" => "name", "label" => "Name", "type" => "text" },
        { "id" => "bio", "label" => "Bio", "type" => "rich_text" }
      ],
      title_field: "name")
    @item = @collection.items.new
    @item.assign_fields("name" => "Ada", "bio" => attachment_html)
    @item.save!
    @item.publish!
  end

  def attachment_html
    %(<p>Hello</p><action-text-attachment sgid="#{@sgid}" content-type="image/png" filename="pic.png" width="1" height="1"></action-text-attachment>)
  end

  def assert_attachment_img(html)
    srcs = Nokogiri::HTML(html).css("img").map { |img| img["src"].to_s }
    assert srcs.any? { |src| src.start_with?("http://cms.example.com/rails/active_storage/") },
      "expected an attachment <img> on the request host, got #{srcs.inspect}"
    refute_includes html, ActiveCanvas::TemplateRenderer::PUBLIC_FALLBACK
    refute_includes html, "example.org"
  end

  test "public show page" do
    get "/canvas/team/#{@item.slug}"
    assert_response :success
    assert_attachment_img(response.body)
  end

  test "public index page rendering rich text" do
    index = @collection.template_pages.find_by!(collection_role: "index")
    index.update!(content: "{% for entry in items %}<div>{{ entry.bio }}</div>{% endfor %}")

    get "/canvas/team"
    assert_response :success
    assert_attachment_img(response.body)
  end

  test "admin item preview" do
    get "/canvas/admin/collections/#{@collection.id}/items/#{@item.id}/preview"
    assert_response :success
    assert_attachment_img(response.body)
  end

  test "regular page bound to the collection" do
    page_type = ActiveCanvas::PageType.create!(name: "Test")
    ActiveCanvas::Page.create!(title: "Team page", slug: "team-page", page_type: page_type, published: true,
      template_enabled: true, content: "{% for member in team %}{{ member.bio }}{% endfor %}",
      bindings: { "team" => { "source" => "team" } })

    get "/canvas/team-page"
    assert_response :success
    assert_attachment_img(response.body)
  end

  test "MCP render_page_preview" do
    page_type = ActiveCanvas::PageType.create!(name: "Test")
    page = ActiveCanvas::Page.create!(title: "Team page", page_type: page_type,
      content: "{% for member in team %}{{ member.bio }}{% endfor %}")

    result, err = mcp_call(mcp_token(%w[read write]), "render_page_preview", {
      page_id: page.id, template_enabled: true, bindings: { team: { source: "team" } }
    })
    assert_nil err
    assert_attachment_img(result["html"])
  end

  test "MCP preview_collection_item" do
    result, err = mcp_call(mcp_token(%w[read write]), "preview_collection_item",
      { collection_id: @collection.id, id: @item.id })
    assert_nil err
    assert_attachment_img(result["html"])
  end
end
