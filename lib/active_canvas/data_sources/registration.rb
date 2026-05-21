module ActiveCanvas
  module DataSources
    # DSL builder used inside DataSources.register blocks.
    class Registration
      def initialize(name)
        @name = name
        @params = {}
        @fetch_block = nil
        @drop_class = nil
        @auto_drop_config = nil
        @on_error = ActiveCanvas.config.template_default_on_error
      end

      def param(name, type:, default: nil, range: nil, allowed: nil)
        @params[name.to_sym] = ParamSpec.new(
          name, source_name: @name, type: type, default: default, range: range, allowed: allowed
        )
      end

      def fetch(&block)
        @fetch_block = block
      end

      def drop(klass)
        @drop_class = klass
      end

      def auto_drop(attributes:, associations: {})
        @auto_drop_config = { attributes: attributes, associations: associations }
      end

      def on_error(mode)
        unless %i[raise silent].include?(mode)
          raise ArgumentError, "on_error must be :raise or :silent, got #{mode.inspect}"
        end
        @on_error = mode
      end

      def to_source
        raise ArgumentError, "fetch block required for data source #{@name.inspect}" unless @fetch_block
        Source.new(
          name: @name,
          params: @params,
          fetch_block: @fetch_block,
          drop_class: @drop_class,
          auto_drop_config: @auto_drop_config,
          on_error: @on_error
        )
      end
    end
  end
end
