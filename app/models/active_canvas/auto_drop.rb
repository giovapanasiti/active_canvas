module ActiveCanvas
  # Generic Liquid Drop wrapper that exposes only declared attributes from any
  # object. String values are HTML-escaped on the way out unless the attribute
  # is listed in `html:` or the value is already html_safe. Associations are
  # off by default; each must be opted in with its own whitelist.
  class AutoDrop < ::Liquid::Drop
    def self.wrap_collection(collection, attributes:, associations: {}, html: [])
      collection.map { |item| new(item, attributes: attributes, associations: associations, html: html) }
    end

    def initialize(record, attributes:, associations: {}, html: [])
      super()
      @record = record
      @attributes = attributes.map(&:to_s).freeze
      @html = html.map(&:to_s).freeze
      @associations = associations.each_with_object({}) do |(key, attrs), acc|
        acc[key.to_s] = attrs
      end.freeze
    end

    # Liquid's hook for property access. Unknown keys return nil so the
    # surface stays tight; in strict preview mode Liquid reports them.
    def liquid_method_missing(method_name)
      if @attributes.include?(method_name)
        escape(read(method_name), method_name)
      elsif @associations.key?(method_name)
        wrap_association(read(method_name), @associations[method_name])
      end
    end

    private

    def read(method_name)
      @record.public_send(method_name) if @record.respond_to?(method_name)
    end

    def escape(value, attribute)
      return value unless value.is_a?(String)
      return value if value.html_safe? || @html.include?(attribute)
      ERB::Util.html_escape(value)
    end

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
