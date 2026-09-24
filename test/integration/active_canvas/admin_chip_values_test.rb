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

  test "reports what each chip displays, the first iteration for loops, and the other copies" do
    content = %(<h1>Hi <span data-ac-var="" data-ac-source="{{ name }}" data-ac-id="c1">{{ name }}</span></h1>) +
      %(<ul><li data-ac-for="r in rows"><span data-ac-var="" data-ac-source="{{ r }}" data-ac-id="c2">{{ r }}</span></li></ul>)
    body = chip_values(content, "name" => { "source" => "_literal", "value" => "<b>World</b>" }, "rows" => { "source" => "_literal", "value" => %w[a b c] })
    assert_response :success
    assert_equal "<b>World</b>", body.dig("values", "c1")   # text, not markup
    assert_equal "a", body.dig("values", "c2")
    assert_nil body["error"]

    loop = body["loops"].first
    assert_equal "r in rows", loop["expr"]
    assert_equal 3, loop["count"]
    assert_equal 2, loop["copies"].size
    assert_match(/\A<li[^>]*>.*b.*<\/li>\z/m, loop["copies"][0])
    refute_match(/data-ac-loop|data-ac-for/, loop["copies"][0])
  end

  test "nested loops report the copies inside the first outer iteration only" do
    content = %(<ul data-ac-for="g in groups"><li data-ac-for="m in g.members">{{ m }}</li></ul>)
    body = chip_values(content, "groups" => { "source" => "_literal", "value" => [ { "members" => %w[a b c] }, { "members" => %w[x] } ] })
    outer, inner = body["loops"]
    assert_equal "g in groups", outer["expr"]
    assert_equal 2, outer["count"]
    assert_equal 1, outer["copies"].size
    assert_includes outer["copies"][0], "x"
    assert_equal "m in g.members", inner["expr"]
    assert_equal 3, inner["count"]
    assert_equal %w[b c], inner["copies"].map { |c| c.gsub(/<[^>]+>/, "") }
  end

  test "copies are capped and the count stays exact" do
    content = %(<li data-ac-for="n in nums">{{ n }}</li>)
    body = chip_values(content, "nums" => { "source" => "_literal", "value" => (1..30).to_a })
    assert_equal 30, body["loops"][0]["count"]
    assert_equal 10, body["loops"][0]["copies"].size
  end

  test "conditions report whether the element renders" do
    content = %(<p data-ac-if="on">yes</p><p data-ac-if="off">no</p><li data-ac-for="r in rows" data-ac-if="r == 'b'">{{ r }}</li>)
    body = chip_values(content, "on" => { "source" => "_literal", "value" => true }, "off" => { "source" => "_literal", "value" => false }, "rows" => { "source" => "_literal", "value" => %w[a b] })
    conds = body["conds"]
    assert_equal [ [ "on", true ], [ "off", false ], [ "r == 'b'", true ] ], conds.map { |c| [ c["expr"], c["shown"] ] }
    assert_equal 1, body["loops"][0]["count"]
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
    assert_equal 0, body["loops"][0]["count"]
    assert_equal [], body["loops"][0]["copies"]
  end

  test "an undefined variable gives an empty value, a syntax error gives an error and no values" do
    body = chip_values(%(<span data-ac-var="" data-ac-source="{{ nope }}" data-ac-id="c1">{{ nope }}</span>), {})
    assert_equal "", body.dig("values", "c1")

    body = chip_values(%({% for x in %}<span data-ac-var="" data-ac-id="c1">x</span>), {})
    assert_response :success
    assert_equal({}, body["values"])
    assert_equal [], body["loops"]
    assert_kind_of String, body["error"]
  end

  test "returns 422 on malformed bindings" do
    post "/canvas/admin/pages/#{@page.id}/chip_values",
      params: { content: "x", bindings: "[1]" }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    assert_response :unprocessable_entity
  end
end
