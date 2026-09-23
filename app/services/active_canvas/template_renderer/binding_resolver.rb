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

      private

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
    end
  end
end
