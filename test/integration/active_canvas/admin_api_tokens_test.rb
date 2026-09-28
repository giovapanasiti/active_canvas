require "test_helper"

class ActiveCanvas::AdminApiTokensTest < ActionDispatch::IntegrationTest
  test "api tokens tab renders the MCP url and snippets" do
    get "/canvas/admin/settings", params: { tab: "api_tokens" }
    assert_response :success
    assert_includes response.body, "/canvas/mcp"
    assert_includes response.body, "claude mcp add --transport http active-canvas"
    assert_includes response.body, "mcp_servers.active_canvas"
    assert_includes response.body, "opencode.json"
  end

  test "creating a token shows the plaintext once, then not on a later GET" do
    assert_difference "ActiveCanvas::ApiToken.count", 1 do
      post "/canvas/admin/api_tokens", params: { name: "agent one", level: "write" }
    end

    assert_redirected_to "/canvas/admin/settings?tab=api_tokens"
    follow_redirect!
    assert_response :success
    assert_select ".api-token-plaintext-value"
    plaintext = css_select(".api-token-plaintext-value").first.text.strip

    token = ActiveCanvas::ApiToken.last
    assert_equal %w[read write], token.scopes
    assert_equal token.token_prefix, plaintext.first(10)

    get "/canvas/admin/settings", params: { tab: "api_tokens" }
    assert_response :success
    assert_select ".api-token-plaintext-value", false
  end

  test "create maps level to scopes for read and publish" do
    post "/canvas/admin/api_tokens", params: { name: "reader", level: "read" }
    assert_equal %w[read], ActiveCanvas::ApiToken.last.scopes

    post "/canvas/admin/api_tokens", params: { name: "publisher", level: "publish" }
    assert_equal %w[read write publish], ActiveCanvas::ApiToken.last.scopes
  end

  test "create records the current editor as created_by" do
    ActiveCanvas::Admin::ApplicationController.class_eval do
      define_method(:active_canvas_current_user) { "editor@example.com" }
    end
    post "/canvas/admin/api_tokens", params: { name: "agent two", level: "read" }
    assert_equal "editor@example.com", ActiveCanvas::ApiToken.last.created_by
  ensure
    ActiveCanvas::Admin::ApplicationController.class_eval { remove_method(:active_canvas_current_user) }
  end

  test "create with a blank name redirects with an alert listing errors" do
    assert_no_difference "ActiveCanvas::ApiToken.count" do
      post "/canvas/admin/api_tokens", params: { name: "", level: "read" }
    end
    assert_redirected_to "/canvas/admin/settings?tab=api_tokens"
    follow_redirect!
    assert_select ".flash-alert"
  end

  test "create with an unknown level redirects with an alert" do
    assert_no_difference "ActiveCanvas::ApiToken.count" do
      post "/canvas/admin/api_tokens", params: { name: "bad level", level: "superuser" }
    end
    assert_redirected_to "/canvas/admin/settings?tab=api_tokens"
    follow_redirect!
    assert_select ".flash-alert"
  end

  test "revoke sets revoked_at and the tab shows Revoked status" do
    token, _plaintext = ActiveCanvas::ApiToken.issue!(name: "to revoke", scopes: %w[read])

    delete "/canvas/admin/api_tokens/#{token.id}"
    assert_redirected_to "/canvas/admin/settings?tab=api_tokens"
    assert token.reload.revoked_at.present?

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Revoked"
  end

  test "a revoked token gets 401 on the MCP endpoint" do
    token, plaintext = ActiveCanvas::ApiToken.issue!(name: "to revoke", scopes: %w[read write publish])
    token.revoke!

    mcp_rpc(plaintext, "tools/list")
    assert_response :unauthorized
  end

  test "the table shows an expired token's status as Expired" do
    ActiveCanvas::ApiToken.issue!(name: "expired", scopes: %w[read], expires_at: 1.day.ago)

    get "/canvas/admin/settings", params: { tab: "api_tokens" }
    assert_response :success
    assert_includes response.body, "Expired"
  end

  test "an active token's status shows as Active" do
    ActiveCanvas::ApiToken.issue!(name: "alive", scopes: %w[read])

    get "/canvas/admin/settings", params: { tab: "api_tokens" }
    assert_response :success
    assert_includes response.body, "Active"
  end

  test "when MCP is disabled, the tab shows a notice" do
    with_config(enable_mcp: false) do
      get "/canvas/admin/settings", params: { tab: "api_tokens" }
      assert_response :success
      assert_includes response.body, "MCP is disabled"
    end
  end

  test "a date-only expires_at is treated as the end of that day" do
    post "/canvas/admin/api_tokens", params: { name: "expires today", level: "read", expires_at: Date.current.iso8601 }
    assert_redirected_to "/canvas/admin/settings?tab=api_tokens"

    token = ActiveCanvas::ApiToken.last
    assert_equal Date.current.end_of_day.to_i, token.expires_at.to_i
    assert token.active?, "a token expiring at the end of today should still be active right after creation"
  end

  test "a past expires_at date is rejected with an alert and no token is created" do
    assert_no_difference "ActiveCanvas::ApiToken.count" do
      post "/canvas/admin/api_tokens", params: { name: "already expired", level: "read", expires_at: 1.day.ago.to_date.iso8601 }
    end

    assert_redirected_to "/canvas/admin/settings?tab=api_tokens"
    follow_redirect!
    assert_select ".flash-alert"
  end

  test "the settings tabs include an API tokens link" do
    get "/canvas/admin/settings", params: { tab: "general" }
    assert_response :success
    assert_select "a[href=?]", "/canvas/admin/settings?tab=api_tokens"
  end
end
