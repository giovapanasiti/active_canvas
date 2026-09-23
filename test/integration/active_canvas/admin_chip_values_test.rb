require "test_helper"

class ActiveCanvas::AdminChipValuesTest < ActionDispatch::IntegrationTest
  setup do
    ActiveCanvas::DataSources.reset_for_testing!
    @page_type = ActiveCanvas::PageType.create!(name: "Test")
    @page = ActiveCanvas::Page.create!(title: "p", page_type: @page_type, content: "", template_enabled: true)
  end
  teardown { ActiveCanvas::DataSources.reset_for_testing! }

  def chip_values(content, bindings)
    post "/canvas/admin/pages/#{@page.id}/chip_values",
      params: { content: content, bindings: bindings.to_json }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    JSON.parse(response.body)
  end

  test "reports what each chip displays, first iteration for loops, and loop counts" do
    content = %(<h1>Hi <span data-ac-var="" data-ac-source="{{ name }}" data-ac-id="c1">{{ name }}</span></h1>) +
      %(<ul><li data-ac-for="r in rows"><span data-ac-var="" data-ac-source="{{ r }}" data-ac-id="c2">{{ r }}</span></li></ul>)
    body = chip_values(content, "name" => { "source" => "_literal", "value" => "<b>World</b>" }, "rows" => { "source" => "_literal", "value" => %w[a b c] })
    assert_response :success
    assert_equal "<b>World</b>", body.dig("values", "c1")   # text, not markup
    assert_equal "a", body.dig("values", "c2")
    assert_equal 3, body.dig("loops", "r in rows")
    assert_nil body["error"]
  end

  test "renders the chip's source even when its text was replaced by a value" do
    content = %(<p><span data-ac-var="" data-ac-source="{{ name }}" data-ac-id="c1">stale value</span></p>)
    body = chip_values(content, "name" => { "source" => "_literal", "value" => "fresh" })
    assert_equal "fresh", body.dig("values", "c1")
  end

  test "a chip inside an empty loop has no value and the loop counts zero" do
    content = %(<ul><li data-ac-for="r in rows"><span data-ac-var="" data-ac-source="{{ r }}" data-ac-id="c2">{{ r }}</span></li></ul>)
    body = chip_values(content, "rows" => { "source" => "_literal", "value" => [] })
    assert_equal({}, body["values"])
    assert_equal 0, body.dig("loops", "r in rows")
  end

  test "an undefined variable gives an empty value, a syntax error gives an error and no values" do
    body = chip_values(%(<span data-ac-var="" data-ac-source="{{ nope }}" data-ac-id="c1">{{ nope }}</span>), {})
    assert_equal "", body.dig("values", "c1")

    body = chip_values(%({% for x in %}<span data-ac-var="" data-ac-id="c1">x</span>), {})
    assert_response :success
    assert_equal({}, body["values"])
    assert_kind_of String, body["error"]
  end

  test "returns 422 on malformed bindings" do
    post "/canvas/admin/pages/#{@page.id}/chip_values",
      params: { content: "x", bindings: "[1]" }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    assert_response :unprocessable_entity
  end
end
