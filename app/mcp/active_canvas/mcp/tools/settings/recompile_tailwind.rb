module ActiveCanvas
  module Mcp
    module Tools
      module Settings
        class RecompileTailwind < BaseTool
          tool_name "recompile_tailwind"
          description "Queue every page with content for a Tailwind CSS recompile. Errors if Tailwind isn't installed or isn't the selected CSS framework."
          input_schema(properties: {})
          required_scope :publish

          def perform(_args)
            ActiveCanvas::TailwindRecompile.call
          rescue ActiveCanvas::TailwindRecompile::Unavailable => e
            fail!(e.message)
          end
        end
      end
    end
  end
end
