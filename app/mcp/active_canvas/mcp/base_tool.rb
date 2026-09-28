module ActiveCanvas
  module Mcp
    # Base class for every ActiveCanvas MCP tool. Subclasses declare
    # tool_name/description/input_schema/annotations/required_scope and
    # implement #perform(args), returning a JSON-serializable Hash or Array.
    #
    # Adaptations from the design sketch, verified against mcp-1.6.1:
    # - `self.call(server_context:, **args)` is the real signature the SDK dispatches
    #   to: `MCP::Server#accepts_server_context?` inspects `tool.method(:call).parameters`
    #   for a `:key`/`:keyreq` named `server_context` (or a `:keyrest`), which our
    #   `server_context:, **args` satisfies. Arguments arrive already symbolized
    #   one level deep (the transport parses JSON with `symbolize_names: true`), and
    #   `Server#call_tool_with_args` also `transform_keys(&:to_sym)`s the top level
    #   defensively, so `args` here is always symbol-keyed.
    # - `server_context` is not a plain Hash: it is an `MCP::ServerContext` wrapping
    #   the Hash we passed to `MCP::Server.new(server_context: { token: token })`.
    #   `ServerContext#method_missing` delegates unknown calls (including `[]` and
    #   `to_h`) to that wrapped Hash when the Hash responds to them, so
    #   `server_context[:token]` resolves correctly without unwrapping anything by
    #   hand; the `.to_h[:token]` fallback below is defensive.
    # - `MCP::Tool::Response#initialize` takes `content` positionally and `error:` as
    #   a keyword (the design sketch's shape matches this exactly).
    # - ToolError/ScopeError live in lib/active_canvas/mcp/errors.rb (classic `require`d
    #   from lib/active_canvas.rb), not app/mcp/.../errors.rb: every app/* directory of
    #   an engine is a Zeitwerk root, and Zeitwerk expects a file named `errors.rb` to
    #   define the single constant `ActiveCanvas::Mcp::Errors`. A file defining two flat
    #   sibling constants (`ToolError`, `ScopeError`) instead would autoload fine on first
    #   reference but raise `Zeitwerk::NameError` the moment anything eager-loads the
    #   engine (e.g. `config.eager_load = true` in production). The gem already has this
    #   exact shape at lib/active_canvas/data_sources/errors.rb, required the same way.
    class BaseTool < MCP::Tool
      MAX_LIMIT = 200
      DEFAULT_LIMIT = 50

      class << self
        def required_scope(scope = nil)
          scope ? @required_scope = scope : @required_scope
        end

        def call(server_context:, **args)
          token = server_context[:token] || server_context.to_h[:token]
          result = new(token).perform(args.with_indifferent_access)
          MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(result.as_json) } ])
        rescue ToolError => e
          error_response(e.message)
        rescue ActiveRecord::RecordNotFound => e
          error_response(record_not_found_message(e))
        rescue ActiveRecord::RecordInvalid => e
          error_response("Validation failed: #{e.record.errors.full_messages.join('; ')}")
        rescue ActiveRecord::RecordNotDestroyed => e
          error_response("Could not delete: #{e.record.errors.full_messages.join('; ')}")
        rescue StandardError => e
          Rails.logger.error("[ActiveCanvas::Mcp] #{name_value} failed: #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
          error_response("Internal error: #{e.class}")
        end

        def error_response(message)
          MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
        end

        # `e.id` may be nil (a `find_by!` with no matching row, no id in the query) or an Array
        # (a `find([1, 2])` bulk lookup, though no tool here does that today); fall back to the
        # plain "<model> not found" whenever there's no single id worth naming.
        def record_not_found_message(e)
          model = e.model&.demodulize || "Record"
          id = e.id
          return "#{model} not found" if id.nil? || id.is_a?(Array)

          "#{model} #{id} not found"
        end
      end

      attr_reader :token

      def initialize(token)
        @token = token
      end

      def perform(_args)
        raise NotImplementedError
      end

      private

      def fail!(message)
        raise ToolError, message
      end

      def require_scope!(scope, reason = nil)
        return if token.scope?(scope)

        raise ScopeError, reason || "This action requires the '#{scope}' scope."
      end

      # A template page's own `published` column is ignored for rendering (it renders
      # whenever its collection has_pages -- Page model docs), so it must be treated
      # the same way for this check: editing a template of a `has_pages` collection
      # changes what's live on the site just like editing a published regular page.
      def require_publish_if_published!(record, noun)
        published = record.respond_to?(:published?) ? record.published? : record.try(:status) == "published"
        published ||= record.is_a?(ActiveCanvas::Page) && record.template? && record.collection.has_pages?
        require_scope!(:publish, "This #{noun} is published; changing it requires the 'publish' scope.") if published
      end

      def paginate(relation, args)
        limit = (args[:limit] || DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)
        offset = [ args[:offset].to_i, 0 ].max
        { items: relation.limit(limit).offset(offset), total: relation.count, limit: limit, offset: offset }
      end

      # Renders a failed PageContentUpdate::Result as a single message: the
      # Liquid error's line/column when the failure was a template validation
      # failure, otherwise the model's joined validation errors. Shared by
      # create_page, update_page_content and restore_page_version.
      def content_update_error(result)
        if result.template_error
          e = result.template_error
          "Liquid error at line #{e[:line]}, column #{e[:column]}: #{e[:message]}"
        else
          result.errors.join("; ")
        end
      end

      # Normalizes a `bindings` argument that may arrive as a Hash or as a
      # JSON string (agents commonly stringify nested objects). Used by the
      # dynamic-data tools. Raises a tool error, not a 500, on bad JSON.
      def parse_bindings(raw)
        ActiveCanvas::PageContentUpdate.parse_bindings(raw) || {}
      rescue JSON::ParserError => e
        fail!("Invalid bindings JSON: #{e.message}")
      end

      # A collection item's `data` argument, with a given `seo` merged in under the
      # reserved "_seo" key CollectionItem#assign_fields expects. Shared by
      # create_collection_item/update_collection_item: `seo`, when given, replaces
      # the whole `_seo` draft value (CollectionItem#assign_fields itself decides
      # per-key trimming/dropping via CollectionSchema#coerce_seo).
      def fields_with_seo(args)
        data = (args[:data] || {}).to_h
        data = data.merge("_seo" => args[:seo]) if args.key?(:seo)
        data
      end
    end
  end
end
