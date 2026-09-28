module ActiveCanvas
  module Mcp
    module Server
      def self.build(token:)
        MCP::Server.new(
          name: "active_canvas",
          title: "ActiveCanvas",
          version: ActiveCanvas::VERSION,
          instructions: Instructions::TEXT,
          tools: Registry.tools_for(token.scopes),
          server_context: { token: token }
        )
      end
    end
  end
end
