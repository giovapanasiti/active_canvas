module ActiveCanvas
  module DataSources
    class ParamSpec
      ALLOWED_TYPES = %i[integer string boolean].freeze

      attr_reader :name, :type, :default, :range, :allowed, :source_name

      def initialize(name, source_name:, type:, default: nil, range: nil, allowed: nil)
        unless ALLOWED_TYPES.include?(type)
          raise ArgumentError, "Param #{name.inspect} type must be one of #{ALLOWED_TYPES.inspect}, got #{type.inspect}"
        end
        @name = name.to_sym
        @source_name = source_name
        @type = type
        @default = default
        @range = range
        @allowed = allowed
      end

      def resolve(params_hash)
        value = params_hash.key?(name) ? params_hash[name] : (params_hash.key?(name.to_s) ? params_hash[name.to_s] : nil)
        coerce(value)
      end

      def coerce(value)
        return default if value.nil?

        coerced = case type
                  when :integer then coerce_integer(value)
                  when :string  then value.to_s
                  when :boolean then coerce_boolean(value)
                  end

        validate!(coerced) unless coerced.nil?
        coerced
      end

      private

      def coerce_integer(value)
        Integer(value)
      rescue ArgumentError, TypeError
        invalid!("not a valid integer: #{value.inspect}")
      end

      def coerce_boolean(value)
        case value
        when true, "true", 1, "1"   then true
        when false, "false", 0, "0" then false
        else invalid!("not a valid boolean: #{value.inspect}")
        end
      end

      def validate!(value)
        invalid!("#{value.inspect} not in range #{range}") if range && !range.include?(value)
        invalid!("#{value.inspect} not in allowed values #{allowed.inspect}") if allowed && !allowed.include?(value)
      end

      def invalid!(reason)
        raise InvalidParam.new(source_name, name, reason)
      end
    end
  end
end
