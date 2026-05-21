module ActiveCanvas
  class TemplateRenderer
    # Walks page.bindings JSON, calls each registered data source, and returns
    # a string-keyed Liquid assigns hash. Refuses to expose raw AR objects.
    class BindingResolver
      def initialize(bindings)
        @bindings = bindings || {}
      end

      def resolve
        @bindings.each_with_object({}) do |(name, spec), acc|
          source_name = spec["source"] || spec[:source]

          if source_name.to_sym == :_literal
            value = spec.key?("value") ? spec["value"] : spec[:value]
            acc[name.to_s] = value
          else
            source = DataSources.lookup(source_name)
            raw_params = symbolize(spec["params"] || spec[:params] || {})
            result = source.call(raw_params)
            acc[name.to_s] = wrap(result, source)
          end
        end
      end

      private

      def symbolize(hash)
        hash.each_with_object({}) { |(k, v), acc| acc[k.to_sym] = v }
      end

      def wrap(result, source)
        if result.is_a?(Enumerable) && !result.is_a?(String) && !result.is_a?(Hash)
          result.map { |item| wrap_one(item, source) }
        else
          wrap_one(result, source)
        end
      end

      def wrap_one(item, source)
        return item if liquid_safe?(item)

        if source.drop_class
          source.drop_class.new(item)
        elsif source.auto_drop_config[:attributes].any?
          AutoDrop.new(
            item,
            attributes: source.auto_drop_config[:attributes],
            associations: source.auto_drop_config[:associations]
          )
        elsif unsafe?(item)
          raise DataSources::UnsafeData.new(source.name, item.class.name)
        else
          item
        end
      end

      def liquid_safe?(item)
        case item
        when ::Liquid::Drop, String, Numeric, TrueClass, FalseClass, NilClass, Symbol, Date, Time, DateTime
          true
        when Hash, Array
          true
        else
          false
        end
      end

      def unsafe?(item)
        item.respond_to?(:attributes) ||
          (defined?(::ActiveRecord::Base) && item.is_a?(::ActiveRecord::Base))
      end
    end
  end
end
