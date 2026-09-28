require "test_helper"

class ActiveCanvas::Mcp::PartialsToolsTest < ActionDispatch::IntegrationTest
  setup { @token = mcp_token(%w[read write publish]) }

  test "list_partials ensures defaults and returns both partials" do
    ActiveCanvas::Partial.delete_all

    listed, err = mcp_call(@token, "list_partials")
    assert_nil err
    types = listed["items"].map { |i| i["partial_type"] }
    assert_includes types, "header"
    assert_includes types, "footer"
    assert_equal 2, listed["total"]
  end

  test "get_partial by id and by partial_type" do
    ActiveCanvas::Partial.ensure_defaults!
    header = ActiveCanvas::Partial.header

    by_id, err = mcp_call(@token, "get_partial", { id: header.id })
    assert_nil err
    assert_equal "header", by_id["partial_type"]

    by_type, err = mcp_call(@token, "get_partial", { partial_type: "header" })
    assert_nil err
    assert_equal header.id, by_type["id"]
  end

  test "get_partial requires id or partial_type" do
    _, err = mcp_call(@token, "get_partial", {})
    assert_match(/id or partial_type/i, err)
  end

  test "update_partial is not callable with only read write scopes" do
    ActiveCanvas::Partial.ensure_defaults!
    header = ActiveCanvas::Partial.header
    rw = mcp_token(%w[read write])

    body = mcp_rpc(rw, "tools/call", { name: "update_partial", arguments: { id: header.id, name: "New name" } })
    assert(body["error"] || body.dig("result", "isError"), "expected update_partial to be unavailable without the publish scope")
  end

  test "update_partial updates content and nils content_components; the model callback recompiles Tailwind" do
    ActiveCanvas::Partial.ensure_defaults!
    header = ActiveCanvas::Partial.header
    header.update!(content_components: '{"foo":"bar"}')

    updated, err = mcp_call(@token, "update_partial", { id: header.id, content: '<div class="text-red-500">Hi</div>' })
    assert_nil err
    assert_equal '<div class="text-red-500">Hi</div>', updated["content"]
    assert_nil updated["content_components"]

    header.reload
    assert_nil header.content_components
    assert_equal '<div class="text-red-500">Hi</div>', header.content

    if ActiveCanvas::TailwindCompiler.available?
      assert header.compiled_css.present?, "expected the Partial#after_save callback to compile Tailwind CSS"
    end
  end

  test "update_partial without a content change leaves content_components untouched" do
    ActiveCanvas::Partial.ensure_defaults!
    header = ActiveCanvas::Partial.header
    header.update!(content: "<p>hi</p>", content_components: '{"foo":"bar"}')

    updated, err = mcp_call(@token, "update_partial", { id: header.id, name: "Renamed header" })
    assert_nil err
    assert_equal "Renamed header", updated["name"]
    assert_equal '{"foo":"bar"}', updated["content_components"]
  end
end
