require "cgi"

module ActiveCanvas
  class TemplateRenderer
    # Walks page.bindings JSON, calls each data source, and returns a
    # string-keyed Liquid assigns hash. Nothing reaches Liquid unless it is a
    # Drop, an escaped scalar, or a Hash/Array made of those.
    class BindingResolver
      def initialize(bindings, silent_errors: false)
        @bindings = bindings || {}
        @silent_errors = silent_errors
      end

      def resolve
        @bindings.each_with_object({}) do |(name, spec), acc|
          acc[name.to_s] = resolve_one(spec)
        end
      end

      # A JSON-friendly peek at one binding for the editor's Data panel: up to
      # `rows` entries, Drops flattened to hashes, escaping undone so the
      # author sees the real text and the real field names.
      def sample(name, rows: 3)
        spec = @bindings[name.to_s] || @bindings[name.to_sym]
        raise DataSources::UnknownSource.new(name) unless spec

        value = resolve_one(sample_spec(spec, rows))
        value.is_a?(Array) ? value.first(rows).map { |v| plain(v) } : plain(value)
      end

      private

      # Caps a collection or param-limited source's `limit` param to the row
      # count so `sample` does not load 100 items to show 3.
      def sample_spec(spec, rows)
        return spec unless spec.is_a?(Hash)

        params = spec["params"] || spec[:params]
        return spec unless params

        source_name = (spec["source"] || spec[:source]).to_s
        cappable = Collection.exists?(slug: source_name) ||
          (DataSources.registered?(source_name) && DataSources.lookup(source_name).params.key?(:limit))
        return spec unless cappable

        spec.merge("params" => params.to_h.merge("limit" => rows))
      end

      def resolve_one(spec)
        raise DataSources::UnknownSource.new(spec.inspect) unless spec.is_a?(Hash)

        source_name = (spec["source"] || spec[:source]).to_s
        raise DataSources::UnknownSource.new(source_name) if source_name.blank?

        params = spec["params"] || spec[:params] || {}
        params = {} unless params.is_a?(Hash)

        if source_name == "_literal"
          to_liquid_value(spec.key?("value") ? spec["value"] : spec[:value])
        elsif DataSources.registered?(source_name)
          fetch(DataSources.lookup(source_name), params)
        elsif (collection = Collection.find_by(slug: source_name))
          to_liquid_value(CollectionSource.new(collection).resolve(params))
        else
          raise DataSources::UnknownSource.new(source_name)
        end
      end

      # Silent sources swallow every StandardError, including InvalidParam and UnsafeData; preview mode still raises.
      def fetch(source, params)
        wrap(source.call(params.to_h.transform_keys(&:to_sym)), source)
      rescue StandardError => e
        raise unless @silent_errors && source.on_error == :silent
        Rails.logger.warn("[ActiveCanvas] data source #{source.name.inspect} failed silently: #{e.class}: #{e.message}")
        nil
      end

      def wrap(result, source)
        if result.is_a?(Array) || result.is_a?(Set) || (result.respond_to?(:to_ary) && !result.is_a?(String))
          result.map { |item| wrap_one(item, source) }
        else
          wrap_one(result, source)
        end
      end

      def wrap_one(item, source)
        return item if item.nil? || item.is_a?(::Liquid::Drop)
        return to_liquid_value(source.drop_class.new(item), source: source) if source.drop_class

        case item
        when ::Liquid::Drop, String, Symbol, Numeric, true, false, nil, Date, Time, Hash, Array
          to_liquid_value(item, source: source)
        else
          if source.auto_drop_config[:attributes].any?
            AutoDrop.new(item, **source.auto_drop_config)
          else
            raise DataSources::UnsafeData.new(source.name, item.class.name)
          end
        end
      end

      # The only door into Liquid. Strings are escaped unless already html_safe,
      # containers are walked, and anything else is refused.
      def to_liquid_value(value, source: nil)
        case value
        when ::Liquid::Drop, Numeric, true, false, nil, Date, Time then value
        when String then value.html_safe? ? value : ERB::Util.html_escape(value)
        when Symbol then ERB::Util.html_escape(value.to_s)
        when Hash   then value.each_with_object({}) { |(k, v), acc| acc[k.to_s] = to_liquid_value(v, source: source) }
        when Array  then value.map { |v| to_liquid_value(v, source: source) }
        else raise DataSources::UnsafeData.new(source&.name || :_literal, value.class.name)
        end
      end

      # Flattens a resolved value for JSON. Drops expose only what Liquid
      # would (`invokable_methods`, zero-arity), depth is capped so a drop
      # that points back at itself cannot recurse, and anything outside the
      # Liquid boundary is rendered as text, never serialized as an object.
      def plain(value, depth = 0)
        case value
        when AutoDrop
          depth > 2 ? value.to_s : plain(value.to_h, depth + 1)
        when ::Liquid::Drop
          return value.to_s if depth > 2
          (value.class.invokable_methods.to_a - [ "to_liquid" ]).sort
            .select { |m| value.method(m).arity.zero? }
            .each_with_object({}) { |m, acc| acc[m.to_s] = plain(value.invoke_drop(m), depth + 1) }
        when Hash   then value.each_with_object({}) { |(k, v), acc| acc[k.to_s] = plain(v, depth + 1) }
        when Array  then value.first(3).map { |v| plain(v, depth + 1) }
        when String then CGI.unescapeHTML(value.to_s)
        when Symbol then value.to_s
        when Numeric, true, false, nil, Date, Time then value
        else value.to_s
        end
      end
    end
  end
end
