module ActiveCanvas
  class TemplateRenderer
    # Walks page.bindings JSON, calls each data source, and returns a
    # string-keyed Liquid assigns hash. Nothing reaches Liquid unless it is a
    # Drop, an escaped scalar, or a Hash/Array made of those.
    class BindingResolver
      # NOTE: silent_errors is a trailing positional hash, not a real keyword
      # parameter. A method with actual keyword params forces every bare hash
      # literal call site (e.g. `BindingResolver.new("x" => { ... })`, used
      # throughout this class's tests) to be parsed as keyword arguments,
      # which breaks with "wrong number of arguments". A plain optional
      # positional hash sidesteps that Ruby 3+ parsing rule while still
      # reading naturally as `BindingResolver.new(bindings, silent_errors: true)`.
      def initialize(bindings, options = {})
        @bindings = bindings || {}
        @silent_errors = options[:silent_errors] || false
      end

      def resolve
        @bindings.each_with_object({}) do |(name, spec), acc|
          acc[name.to_s] = resolve_one(spec)
        end
      end

      private

      def resolve_one(spec)
        source_name = (spec["source"] || spec[:source]).to_s
        raise DataSources::UnknownSource.new(source_name) if source_name.blank?

        params = spec["params"] || spec[:params] || {}

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

      def fetch(source, params)
        wrap(source.call(params.to_h.transform_keys(&:to_sym)), source)
      rescue StandardError => e
        raise unless @silent_errors && source.on_error == :silent
        Rails.logger.warn("[ActiveCanvas] data source #{source.name.inspect} failed silently: #{e.class}: #{e.message}")
        nil
      end

      def wrap(result, source)
        if result.is_a?(Enumerable) && !result.is_a?(String) && !result.is_a?(Hash)
          result.map { |item| wrap_one(item, source) }
        else
          wrap_one(result, source)
        end
      end

      def wrap_one(item, source)
        case item
        when ::Liquid::Drop, String, Symbol, Numeric, true, false, nil, Date, Time, Hash, Array
          to_liquid_value(item, source: source)
        else
          if source.drop_class
            source.drop_class.new(item)
          elsif source.auto_drop_config[:attributes].any?
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
    end
  end
end
