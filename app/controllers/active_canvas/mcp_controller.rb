module ActiveCanvas
  # Stateless Streamable-HTTP MCP endpoint. Authenticates a bearer ApiToken and
  # hands the raw request to the official SDK transport with a server whose
  # tool list is filtered by the token's scopes.
  class McpController < ActionController::API
    include ActiveCanvas::RateLimitable

    # This action never reads from `params`, only the raw request body handed to the SDK
    # transport - the wrapped-parameters duplicate Rails would otherwise build under the
    # controller/action name is dead weight, and skipping it means one less place a JSON-RPC
    # body's sensitive fields (upload_media's data_base64, update_ai_settings' api keys) could
    # show up unfiltered.
    wrap_parameters false

    before_action :ensure_enabled
    before_action :authenticate_token
    before_action -> { check_rate_limit(namespace: "mcp", limit: ActiveCanvas.config.mcp_rate_limit_per_minute) }
    around_action :with_request_scoped_renderer

    def handle
      ActiveCanvas::Current.editor = "MCP: #{@token.name}"
      @token.touch_last_used!

      server = ActiveCanvas::Mcp::Server.build(token: @token)
      # The SDK's `dns_rebinding_protection` (Host/Origin header checks) guards an unauthenticated
      # local server against a browser-based attacker whose page gets a victim's browser to POST to
      # it under a rebound DNS name or a same-origin-looking Origin. That vector doesn't apply here:
      # auth is a bearer token, and a browser cannot attach an `Authorization` header to a
      # cross-origin request without a CORS preflight - which this endpoint never answers (no
      # `Access-Control-Allow-Origin`/`-Headers`), so the browser refuses to send the real request at
      # all. There is also no ambient credential (cookie/session) a rebound page could ride on
      # instead. Building the transport's allow-list from the very request it validates
      # (`allowed_hosts: [request.host]`) would not add protection - it always matches - so the check
      # is off explicitly rather than left misleadingly "on" via a check that can never reject
      # anything. Note this also disables the SDK's `Origin` check, which the reasoning above covers
      # too. This is unrelated to Rails' own `config.hosts` (HostAuthorization middleware): that only
      # enforces anything when the host app sets it, and does so for every route, not specifically
      # this one - it is not what makes disabling `dns_rebinding_protection` safe here.
      # The SDK's `max_request_bytes` bounds the raw JSON-RPC request body it reads into memory
      # (4 MiB by default). A base64-encoded upload inflates its decoded byte size by ~4/3, so the
      # default cap would 413 an upload well under `max_upload_size` (e.g. a ~3.1 MB image already
      # exceeds the 4 MiB default once base64-encoded and wrapped in the JSON-RPC envelope). Size
      # the transport's cap off the configured upload limit instead, with headroom for the JSON-RPC
      # envelope and tool-call metadata around the base64 payload, and never go below the SDK's own
      # default so a small `max_upload_size` cannot shrink the cap below what non-upload calls need.
      max_request_bytes = [ (ActiveCanvas.config.max_upload_size * 4 / 3) + 256.kilobytes,
                            MCP::Server::Transports::StreamableHTTPTransport::DEFAULT_MAX_REQUEST_BYTES ].max
      transport = MCP::Server::Transports::StreamableHTTPTransport.new(
        server, stateless: true, dns_rebinding_protection: false, max_request_bytes: max_request_bytes
      )
      status, headers, body = transport.handle_request(request)

      headers.each { |k, v| response.headers[k] = v }
      self.status = status
      self.response_body = body
    end

    private

    # Rich text attachments and preview renders use this request's host
    # (ActionController::API never gets Action Text's own renderer hook).
    def with_request_scoped_renderer(&block)
      ActiveCanvas::RequestScopedRenderer.around(request, &block)
    end

    def ensure_enabled
      render json: { error: "MCP is disabled" }, status: :not_found unless ActiveCanvas.config.enable_mcp
    end

    def authenticate_token
      plaintext = request.authorization.to_s[/\ABearer\s+(.+)\z/, 1]
      @token = ActiveCanvas::ApiToken.authenticate(plaintext)
      return if @token

      response.headers["WWW-Authenticate"] = 'Bearer realm="ActiveCanvas MCP"'
      render json: { error: "Invalid or missing API token" }, status: :unauthorized
    end

    # Keyed by token rather than IP: agents often share egress IPs.
    def rate_limit_cache_key(namespace)
      "active_canvas:rate_limit:#{namespace}:token:#{@token.id}"
    end

    def render_rate_limit_exceeded(exception)
      render json: { error: exception.message }, status: :too_many_requests
    end
  end
end
