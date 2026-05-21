module ActiveCanvas
  # Generic Liquid Drop wrapper that exposes only declared attributes from any
  # object. Associations are off by default; each must be opted in with its own
  # whitelist.
  class AutoDrop < ::Liquid::Drop
    def self.wrap_collection(collection, attributes:, associations: {})
      collection.map { |item| new(item, attributes: attributes, associations: associations) }
    end

    def initialize(record, attributes:, associations: {})
      super()
      @record = record
      @attributes = attributes.map(&:to_s).freeze
      @associations = associations.each_with_object({}) do |(key, attrs), acc|
        acc[key.to_s] = attrs
      end.freeze
    end

    # Liquid's hook for property access. Returning nil for unknown keys keeps
    # the surface tight: editors get an undefined-variable error in strict mode.
    def liquid_method_missing(method_name)
      if @attributes.include?(method_name)
        @record.public_send(method_name)
      elsif @associations.key?(method_name)
        wrap_association(@record.public_send(method_name), @associations[method_name])
      end
    end

    private

    def wrap_association(value, attrs)
      if value.nil?
        nil
      elsif value.is_a?(Array) || (value.respond_to?(:to_ary) && !value.is_a?(String))
        AutoDrop.wrap_collection(value, attributes: attrs)
      else
        AutoDrop.new(value, attributes: attrs)
      end
    end
  end
end
