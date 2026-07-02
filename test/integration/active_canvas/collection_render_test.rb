require "test_helper"

class ActiveCanvas::CollectionRenderTest < ActionDispatch::IntegrationTest
  setup do
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @collection = ActiveCanvas::Collection.create!(name: "Team", slug: "team",
      fields: [ { "label" => "Name", "type" => "text" } ])
  end

  def add_item(name, publish:)
    item = @collection.items.new
    item.assign_fields("name" => name)
    item.save!
    item.publish! if publish
    item
  end

  test "page loops over a collection and renders published item values" do
    add_item("Ada", publish: true)
    add_item("Grace", publish: true)
    add_item("Draft Only", publish: false)

    page = ActiveCanvas::Page.create!(
      title: "Team page", slug: "team-page", page_type: @page_type, published: true,
      template_enabled: true,
      bindings: { "team" => { "source" => "team", "params" => { "sort_field" => "name", "sort_dir" => "asc" } } },
      content: "<ul>{% for member in team %}<li>{{ member.name }}</li>{% endfor %}</ul>"
    )

    get "/canvas/#{page.slug}"
    assert_response :success
    assert_includes response.body, "<li>Ada</li>"
    assert_includes response.body, "<li>Grace</li>"
    refute_includes response.body, "Draft Only"
  end

  test "unpublishing an item removes it from the rendered page" do
    item = add_item("Ada", publish: true)
    page = ActiveCanvas::Page.create!(
      title: "T", slug: "t", page_type: @page_type, published: true, template_enabled: true,
      bindings: { "team" => { "source" => "team", "params" => {} } },
      content: "{% for m in team %}{{ m.name }}{% endfor %}"
    )

    get "/canvas/t"
    assert_includes response.body, "Ada"

    item.unpublish!
    get "/canvas/t"
    refute_includes response.body, "Ada"
  end

  test "a deleted collection degrades to the public fallback, not a 500" do
    page = ActiveCanvas::Page.create!(
      title: "T2", slug: "t2", page_type: @page_type, published: true, template_enabled: true,
      bindings: { "gone" => { "source" => "gone", "params" => {} } },
      content: "{% for x in gone %}{{ x.name }}{% endfor %}"
    )
    get "/canvas/t2"
    assert_response :success
    assert_includes response.body, "dynamic block unavailable"
  end
end
