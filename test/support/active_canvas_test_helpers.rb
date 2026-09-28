require "stringio"

module ActiveCanvasTestHelpers
  # Build and persist a Media with an attached fake file.
  def build_saved_media(filename: "sample.png", content_type: "image/png")
    media = ActiveCanvas::Media.new(filename: filename)
    media.file.attach(
      io: StringIO.new("fake-bytes-#{filename}"),
      filename: filename,
      content_type: content_type
    )
    media.save!
    media
  end

  # Temporarily override ActiveCanvas.config attributes, restoring afterwards.
  def with_config(**overrides)
    config = ActiveCanvas.config
    previous = overrides.keys.index_with { |k| config.public_send(k) }
    overrides.each { |k, v| config.public_send("#{k}=", v) }
    yield
  ensure
    previous.each { |k, v| config.public_send("#{k}=", v) }
  end

  # Capture Rails.logger output produced inside the block.
  #
  # Also repoints ActionController::Base's logger: `ActionController::LogSubscriber#logger`
  # reads `ActionController::Base.logger` (set once from `Rails.logger` at boot, via
  # `config.logger`), not `Rails.logger` itself, so a controller request's "Processing by" /
  # "Parameters:" lines would otherwise keep going to the original logger, ignoring a
  # `Rails.logger =` swap here.
  def capture_log
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    previous = Rails.logger
    previous_controller_logger = ActionController::Base.logger
    Rails.logger = logger
    ActionController::Base.logger = logger
    yield
    io.string
  ensure
    Rails.logger = previous
    ActionController::Base.logger = previous_controller_logger
  end

  def default_page_type
    ActiveCanvas::PageType.find_or_create_by!(key: "default") { |pt| pt.name = "Default" }
  end

  def create_page(content:, title: "Test Page")
    ActiveCanvas::Page.create!(title: title, page_type: default_page_type, content: content)
  end

  # Issues a fresh MCP API token and returns only the plaintext (the record is
  # discarded; callers that need to revoke/inspect it call ApiToken.issue! directly).
  def mcp_token(scopes = %w[read write publish], name: "agent")
    ActiveCanvas::ApiToken.issue!(name: name, scopes: scopes).last
  end

  # Posts one JSON-RPC request to the MCP endpoint; returns the parsed JSON-RPC response Hash.
  #
  # No `initialize` handshake is sent first: the SDK's stateless transport accepts any method
  # once the `MCP-Protocol-Version` header is absent or names a supported *stable* version (it
  # then falls back to `Configuration::DEFAULT_NEGOTIATED_PROTOCOL_VERSION`, "2025-03-26" in
  # mcp 1.6.1) - see `StreamableHTTPTransport#validate_protocol_version_header`. So a bare
  # `tools/list`/`tools/call` without a prior `initialize` is valid in stateless mode and needs
  # no adaptation here.
  def mcp_rpc(plaintext, method, params = {}, id: 1)
    post "/canvas/mcp",
      params: { jsonrpc: "2.0", id: id, method: method, params: params }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream",
                 "Authorization" => "Bearer #{plaintext}" }
    JSON.parse(response.body)
  end

  # Calls a tool; returns [payload_hash_or_nil, error_message_or_nil].
  def mcp_call(plaintext, tool, args = {})
    result = mcp_rpc(plaintext, "tools/call", { name: tool, arguments: args })["result"]
    text = result["content"].first["text"]
    result["isError"] ? [ nil, text ] : [ JSON.parse(text), nil ]
  end

  def mcp_tool_names(plaintext)
    mcp_rpc(plaintext, "tools/list")["result"]["tools"].map { |t| t["name"] }
  end

  # Collects real SQL statements (skipping cached queries, transaction control, and schema
  # introspection) executed inside the block, to assert a list endpoint preloads an
  # association/setting in a flat number of queries rather than one per row (N+1).
  # Deliberately counts cached repeats too (not just real DB round-trips): Rails'
  # per-request query cache would otherwise mask an N+1 whose repeated rows share the same
  # SQL+binds (e.g. every row pointing at the same associated record), hiding exactly the
  # bug this is meant to catch.
  def collect_sql_queries
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name] == "SCHEMA"
      next if /\A(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i.match?(payload[:sql].to_s.strip)
      statements << payload[:sql]
    end
    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def count_sql_queries(&block)
    collect_sql_queries(&block).size
  end

  # Minimal stand-in for Minitest::Mock#stub (not bundled with the pinned
  # minitest version here): replaces a singleton method on `object` with
  # `val_or_callable` (a value, or something #call-able) for the duration of
  # the block, restoring the original method afterwards.
  def stub_method(object, method_name, val_or_callable)
    original = object.method(method_name) if object.respond_to?(method_name, true)
    replacement = val_or_callable.respond_to?(:call) ? val_or_callable : ->(*) { val_or_callable }

    object.define_singleton_method(method_name) { |*args, **kwargs, &blk| replacement.call(*args, **kwargs, &blk) }
    yield
  ensure
    if original
      object.define_singleton_method(method_name, original)
    else
      object.singleton_class.send(:remove_method, method_name)
    end
  end
end
