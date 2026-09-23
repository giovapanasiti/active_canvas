module ActiveCanvas
  module DataSources
    class Source
      attr_reader :name, :params, :drop_class, :auto_drop_config, :on_error

      def initialize(name:, params:, fetch_block:, drop_class:, auto_drop_config:, on_error:, returns: :list)
        @name = name
        @params = params
        @fetch_block = fetch_block
        @drop_class = drop_class
        @auto_drop_config = auto_drop_config || { attributes: [], associations: {}, html: [] }
        @on_error = on_error
        @returns = returns
      end

      def list?
        @returns == :list
      end

      # Resolves params (with defaults + validation) then calls the fetch block.
      def call(raw_params)
        resolved = {}
        params.each do |pname, spec|
          resolved[pname] = spec.resolve(raw_params || {})
        end
        # Pass as keyword args if the block expects them, else positional.
        if @fetch_block.parameters.any? { |type, _| type == :keyreq || type == :key }
          @fetch_block.call(**resolved)
        else
          @fetch_block.call
        end
      end

      # JSON-friendly description of the params for the editor's Data panel.
      def param_schema
        params.transform_values do |spec|
          {
            type: spec.type,
            default: spec.default,
            range: spec.range && [ spec.range.min, spec.range.max ],
            allowed: spec.allowed
          }
        end
      end
    end
  end
end
