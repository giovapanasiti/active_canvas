require "concurrent/map"

module ActiveCanvas
  module DataSources
    @registry = Concurrent::Map.new
    @frozen   = false

    class << self
      def register(name, &block)
        name = name.to_sym
        raise RegistryFrozen.new(name) if @frozen
        builder = Registration.new(name)
        builder.instance_eval(&block)
        @registry[name] = builder.to_source
      end

      def lookup(name)
        @registry[name.to_sym] || raise(UnknownSource.new(name))
      end

      def registered_names
        @registry.keys.sort
      end

      def each(&block)
        @registry.each_pair(&block)
      end

      def freeze!
        register_literal_source unless @registry.key?(:_literal)
        @frozen = true
      end

      def frozen?
        @frozen
      end

      def reset_for_testing!
        @registry = Concurrent::Map.new
        @frozen = false
        register_literal_source
      end

      private

      def register_literal_source
        builder = Registration.new(:_literal)
        builder.param :value, type: :string, default: nil
        builder.fetch { |value:| value }
        @registry[:_literal] = builder.to_source
      end
    end

    # Bootstrap the literal pseudo source at load time using the explicit form.
    # This ensures _literal exists from the moment the module loads, before any
    # host initializer runs. We construct Source directly to avoid triggering
    # Registration#initialize which calls ActiveCanvas.config (not yet available
    # at require time, since this file is required before the module body runs).
    @registry[:_literal] = Source.new(
      name: :_literal,
      params: { value: ParamSpec.new(:value, source_name: :_literal, type: :string, default: nil) },
      fetch_block: ->(value:) { value },
      drop_class: nil,
      auto_drop_config: nil,
      on_error: :raise
    )
  end
end
