require "test_helper"

class ActiveCanvas::DynamicPageRenderTest < ActionDispatch::IntegrationTest
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    @engine = ActiveCanvas::Engine
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
  end
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  test "dynamic page renders with binding values" do
    page = ActiveCanvas::Page.create!(
      title: "Dynamic", slug: "dyn", page_type: @page_type,
      content: "Hello {{ name }}!",
      published: true, template_enabled: true,
      bindings: { "name" => { "source" => "_literal", "value" => "World" } }
    )
    get "/canvas/#{page.slug}"
    assert_response :success
    assert_includes response.body, "Hello World!"
  end

  test "dynamic page sets Cache-Control: no-store" do
    page = ActiveCanvas::Page.create!(
      title: "Dynamic", slug: "dyn2", page_type: @page_type,
      content: "x", published: true, template_enabled: true
    )
    get "/canvas/#{page.slug}"
    assert_match(/no-store/, response.headers["Cache-Control"].to_s)
  end

  test "static page does NOT set Cache-Control: no-store" do
    page = ActiveCanvas::Page.create!(
      title: "Static", slug: "stat", page_type: @page_type,
      content: "x", published: true, template_enabled: false
    )
    get "/canvas/#{page.slug}"
    refute_match(/no-store/, response.headers["Cache-Control"].to_s)
  end

  test "an undefined variable renders empty on the public page" do
    page = ActiveCanvas::Page.create!(
      title: "Dynamic", slug: "broken", page_type: @page_type,
      content: "<p>Hello {{ missing_var }}!</p>",
      published: true, template_enabled: true
    )
    get "/canvas/#{page.slug}"
    assert_response :success
    assert_includes response.body, "<p>Hello !</p>"
    refute_includes response.body, "dynamic block unavailable"
  end

  test "an unknown data source soft-fails to the fallback comment" do
    page = ActiveCanvas::Page.create!(
      title: "Dynamic", slug: "broken2", page_type: @page_type,
      content: "Hello {{ x }}!",
      published: true, template_enabled: true,
      bindings: { "x" => { "source" => "does_not_exist" } }
    )
    get "/canvas/#{page.slug}"
    assert_response :success
    assert_includes response.body, "<!-- dynamic block unavailable -->"
  end
end
