require "test_helper"

class ActiveCanvas::Mcp::TransportTest < ActionDispatch::IntegrationTest
  # The dummy app's test environment uses `:null_store` (nothing persists across requests),
  # so the rate-limit test below needs a real cache to count against, same as the existing
  # pattern in test/integration/active_canvas/form_submissions_test.rb.
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @original_cache }

  test "rejects missing, unknown, revoked and expired tokens with 401" do
    post "/canvas/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
      headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
    assert_equal "Bearer", response.headers["WWW-Authenticate"].split.first

    mcp_rpc("ac_nope", "tools/list")
    assert_response :unauthorized

    token, plaintext = ActiveCanvas::ApiToken.issue!(name: "a", scopes: %w[read])
    token.revoke!
    mcp_rpc(plaintext, "tools/list")
    assert_response :unauthorized

    _, plaintext = ActiveCanvas::ApiToken.issue!(name: "b", scopes: %w[read], expires_at: 1.minute.from_now)
    travel 2.minutes do
      mcp_rpc(plaintext, "tools/list")
      assert_response :unauthorized
    end
  end

  test "returns 404 when MCP is disabled" do
    plaintext = mcp_token
    with_config(enable_mcp: false) do
      mcp_rpc(plaintext, "tools/list")
      assert_response :not_found
    end
  end

  test "rate limits per token" do
    plaintext = mcp_token
    with_config(mcp_rate_limit_per_minute: 2) do
      2.times { mcp_rpc(plaintext, "tools/list"); assert_response :success }
      mcp_rpc(plaintext, "tools/list")
      assert_response :too_many_requests
    end
  end

  test "initialize returns server info and instructions" do
    body = mcp_rpc(mcp_token, "initialize", {
      protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" }
    })
    assert_equal "active_canvas", body.dig("result", "serverInfo", "name")
    assert body.dig("result", "instructions").present?
  end

  test "tools/list is filtered by scope" do
    read_names = mcp_tool_names(mcp_token(%w[read]))
    write_names = mcp_tool_names(mcp_token(%w[read write]))
    assert_includes read_names, "list_page_types"
    refute_includes read_names, "create_page_type"
    assert_includes write_names, "create_page_type"
  end

  test "a token revoked between calls loses access immediately" do
    token, plaintext = ActiveCanvas::ApiToken.issue!(name: "a", scopes: %w[read write])
    mcp_rpc(plaintext, "tools/list")
    assert_response :success
    token.revoke!
    mcp_rpc(plaintext, "tools/list")
    assert_response :unauthorized
  end

  test "works behind a production-like Host header" do
    host! "cms.example.com"
    mcp_rpc(mcp_token, "tools/list")
    assert_response :success
  end

  test "GET is not allowed in stateless mode" do
    get "/canvas/mcp", headers: { "Authorization" => "Bearer #{mcp_token}" }
    assert_includes [ 405, 404 ], response.status
  end

  test "a page with slug 'mcp' does not hijack the endpoint" do
    ActiveCanvas::Page.create!(title: "M", slug: "mcp", page_type: default_page_type, published: true)
    mcp_rpc(mcp_token, "tools/list")
    assert_response :success
  end

  # The SDK's transport defaults to a 4 MiB request body cap (DEFAULT_MAX_REQUEST_BYTES); a
  # base64-encoded upload inflates ~4/3 over its decoded size, so a ~3.5 MB upload well under the
  # default 10 MB `max_upload_size` produces a JSON-RPC body over 4 MiB and must not be rejected at
  # the transport layer with a 413 - only `max_upload_size` itself (a tool-level error) should ever
  # reject it.
  test "a request body just over the SDK's 4 MiB transport default is not rejected with 413" do
    assert_equal 10.megabytes, ActiveCanvas.config.max_upload_size

    large_base64 = Base64.strict_encode64(SecureRandom.random_bytes(3.5.megabytes.to_i))
    assert_operator large_base64.bytesize, :>, 4.megabytes

    _, err = mcp_call(mcp_token, "upload_media", { filename: "big.bin", data_base64: large_base64 })
    assert_response :success
    # A tool-level error (e.g. content-type sniffing) is fine; a transport 413 is not.
    refute_equal 413, response.status
    refute_match(/payload too large/i, err.to_s)
  end

  test "sensitive tool arguments are filtered out of the request log" do
    token = mcp_token(%w[read write publish])
    tiny_png_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

    output = capture_log do
      mcp_call(token, "upload_media", { filename: "pixel.png", data_base64: tiny_png_base64 })
      mcp_call(token, "update_ai_settings", { openai_api_key: "sk-super-secret-key" })
    end

    refute_includes output, tiny_png_base64
    refute_includes output, "sk-super-secret-key"
    assert_includes output, "FILTERED"
  end
end
