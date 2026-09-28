require "test_helper"

class ActiveCanvas::AdminPreviewIframeTest < ActionDispatch::IntegrationTest
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
  end
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "renders a dynamic page with the editor's unsaved state" do
    page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "", template_enabled: true)
    post "/canvas/admin/pages/#{page.id}/preview_iframe",
      params: { content: "<p>Hi {{ name }}</p>", bindings: { name: { source: "_literal", value: "Liz" } }.to_json }
    assert_response :success
    assert_includes JSON.parse(response.body)["html"], "<p>Hi Liz</p>"
  end

  test "does not force dynamic rendering on a static page" do
    page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "", template_enabled: false)
    post "/canvas/admin/pages/#{page.id}/preview_iframe",
      params: { content: "<p>{{ name }}</p>", bindings: { name: { source: "_literal", value: "Liz" } }.to_json }
    assert_response :success
    assert_includes JSON.parse(response.body)["html"], "{{ name }}"
  end

  test "returns 422 on malformed bindings" do
    page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "", template_enabled: true)
    post "/canvas/admin/pages/#{page.id}/preview_iframe", params: { content: "x", bindings: "[1]" }
    assert_response :unprocessable_entity
  end

  test "a static page preview is sanitized like a save" do
    page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "", template_enabled: false)
    post "/canvas/admin/pages/#{page.id}/preview_iframe", params: { content: "<p>ok</p><script>alert(1)</script>" }
    assert_response :success
    html = JSON.parse(response.body)["html"]
    assert_includes html, "<p>ok</p>"
    refute_includes html, "<script>alert(1)</script>"
  end

  test "a dynamic page preview keeps Liquid inside tables" do
    page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "", template_enabled: true)
    post "/canvas/admin/pages/#{page.id}/preview_iframe",
      params: { content: "<table><tbody>{% for r in rows %}<tr><td>{{ r }}</td></tr>{% endfor %}</tbody></table>",
                bindings: { rows: { source: "_literal", value: %w[a b] } }.to_json }
    assert_response :success
    assert_includes JSON.parse(response.body)["html"], "<tr><td>a</td></tr><tr><td>b</td></tr>"
  end

  test "renders a rich_text attachment's URL against the real request host, not the bare-renderer placeholder" do
    host! "cms.example.com"

    media = build_saved_media(filename: "pic.png", content_type: "image/png")
    sgid = media.file.blob.attachable_sgid
    team = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "id" => "bio", "label" => "Bio", "type" => "rich_text" } ])
    item = team.items.new
    item.assign_fields("bio" => %(<action-text-attachment sgid="#{sgid}" content-type="image/png" filename="pic.png" width="1" height="1"></action-text-attachment>))
    item.save!
    item.publish!

    page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "", template_enabled: true)
    post "/canvas/admin/pages/#{page.id}/preview_iframe",
      params: { content: "{% for member in team %}{{ member.bio }}{% endfor %}",
                bindings: { team: { source: "team" } }.to_json }

    assert_response :success
    html = JSON.parse(response.body)["html"]
    assert_includes html, "cms.example.com"
    refute_includes html, "example.org"
  end
end
