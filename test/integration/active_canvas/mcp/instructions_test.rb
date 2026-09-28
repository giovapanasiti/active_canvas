require "test_helper"

class ActiveCanvas::Mcp::InstructionsTest < ActionDispatch::IntegrationTest
  test "initialize returns instructions covering media refs, dynamic pages, validation and publishing" do
    body = mcp_rpc(mcp_token, "initialize", {
      protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" }
    })
    instructions = body.dig("result", "instructions")

    assert_includes instructions, "data-ac-media-id"
    assert_includes instructions, "template_enabled"
    assert_includes instructions, "validate_template"
    assert_includes instructions, "publish"
  end

  test "the instructions cover collection pages: reserved names, url shape and item seo" do
    body = mcp_rpc(mcp_token, "initialize", {
      protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" }
    })
    instructions = body.dig("result", "instructions")

    assert_includes instructions, "has_pages"
    assert_includes instructions, "preview_collection_item"
    assert_includes instructions, "reserved names"
    assert_includes instructions, "<collection-slug>"
    assert_includes instructions, "og_image_media_id"
  end

  test "the instructions do not claim partial saves are versioned" do
    body = mcp_rpc(mcp_token, "initialize", {
      protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" }
    })
    instructions = body.dig("result", "instructions")

    assert_includes instructions, "Versions exist for pages only"
    assert_includes instructions, "cannot be undone via restore"
    refute_match(/partial.{0,40}creates? a version/im, instructions)
  end

  # Pins the instructions' `_literal` binding example to real behavior: the binding shape
  # shown there — `{ "source" => "_literal", "value" => "Welcome" }` (a top-level `value`,
  # not `params.value`) — must actually resolve to "Welcome" when rendered, per
  # BindingResolver#resolve_one.
  test "the _literal binding example from the instructions renders its value" do
    token = mcp_token
    page, err = mcp_call(token, "create_page", {
      title: "Instructions example",
      content: "{{ hero }}",
      template_enabled: true,
      bindings: { hero: { source: "_literal", value: "Welcome" } }
    })
    assert_nil err

    preview, err = mcp_call(token, "render_page_preview", { page_id: page["id"] })
    assert_nil err
    assert_includes preview["html"], "Welcome"
  end
end
