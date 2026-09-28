module ActiveCanvas
  module Mcp
    # Discovers every concrete BaseTool subclass and filters it by the calling
    # token's scopes. `required_scope` is the only static gate; tools with a
    # state-dependent requirement (e.g. mutating a published page) additionally
    # call `require_scope!` at call time (see BaseTool).
    module Registry
      TOOLS_DIR = "app/mcp/active_canvas/mcp/tools".freeze

      def self.tools_for(scopes)
        load_tools!
        granted = Array(scopes).map(&:to_sym)
        BaseTool.descendants.select { |t| t.required_scope && granted.include?(t.required_scope) }.sort_by(&:name_value)
      end

      def self.load_tools!
        # When `config.eager_load` is true (production, and CI here), every app/* directory -
        # including this one - was already eager-loaded at boot; doing it again per-request is
        # redundant work for no benefit (the tools are already loaded and never unloaded).
        return if Rails.application.config.eager_load

        Rails.autoloaders.main.eager_load_dir(ActiveCanvas::Engine.root.join(TOOLS_DIR).to_s)
      end
    end
  end
end
