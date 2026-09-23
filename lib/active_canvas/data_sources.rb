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

      def registered?(name)
        @registry.key?(name.to_sym)
      end

      def registered_names
        @registry.keys.sort
      end

      def each(&block)
        @registry.each_pair(&block)
      end

      # Default loop variable for a binding: `articles` → `article`, and
      # `item` when the singular is no different (`team`).
      def item_name(name)
        singular = name.to_s.singularize
        singular.present? && singular != name.to_s ? singular : "item"
      end

      def freeze!
        @frozen = true
      end

      def frozen?
        @frozen
      end

      def reset_for_testing!
        @registry = Concurrent::Map.new
        @frozen = false
      end
    end
  end
end
