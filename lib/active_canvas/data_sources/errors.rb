module ActiveCanvas
  module DataSources
    class Error < StandardError; end

    class UnknownSource < Error
      def initialize(name)
        super("Unknown data source: #{name.inspect}")
        @name = name
      end
      attr_reader :name
    end

    class InvalidParam < Error
      def initialize(source_name, param_name, reason)
        super("Data source #{source_name.inspect} param #{param_name.inspect}: #{reason}")
        @source_name = source_name
        @param_name = param_name
      end
      attr_reader :source_name, :param_name
    end

    class UnsafeData < Error
      def initialize(source_name, object_class)
        super(
          "Data source #{source_name.inspect} returned a #{object_class} object without a Drop wrapper. " \
          "Wrap results with auto_drop or a custom Liquid::Drop subclass."
        )
        @source_name = source_name
        @object_class = object_class
      end
      attr_reader :source_name, :object_class
    end

    class RegistryFrozen < Error
      def initialize(name)
        super("Cannot register data source #{name.inspect} after boot. Move the registration into config/initializers/active_canvas.rb.")
      end
    end

    class TemplateRenderError < StandardError
      attr_reader :line, :column, :original

      def initialize(message, line: nil, column: nil, original: nil)
        super(message)
        @line = line
        @column = column
        @original = original
      end
    end
  end
end
