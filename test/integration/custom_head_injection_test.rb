require "test_helper"

class CustomHeadInjectionTest < ActionDispatch::IntegrationTest
  setup do
    @page_type = ActiveCanvas::PageType.create!(key: "default", name: "Default")
    @page = ActiveCanvas::Page.create!(
      title: "Head Test", slug: "head-test", published: true,
      page_type: @page_type, content: "<p>hi</p>"
    )
  end

  teardown { ActiveCanvas::Setting.custom_head_html = "" }

  test "public page renders successfully (smoke)" do
    get "/canvas/head-test"
    assert_response :success
  end

  test "custom head html is injected into the public page head" do
    ActiveCanvas::Setting.custom_head_html = '<meta name="ac-head-test" content="yes">'
    get "/canvas/head-test"
    assert_response :success
    head = response.body[/<head.*?<\/head>/m]
    assert_includes head, '<meta name="ac-head-test" content="yes">'
  end

  test "nothing extra injected when custom head html is blank" do
    ActiveCanvas::Setting.custom_head_html = ""
    get "/canvas/head-test"
    assert_response :success
    refute_includes response.body, "ac-head-test"
  end
end
