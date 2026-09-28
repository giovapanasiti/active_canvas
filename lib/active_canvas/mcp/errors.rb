module ActiveCanvas
  module Mcp
    # Raised by a tool's #perform to end the call with a readable message, surfaced
    # by BaseTool.call as an MCP::Tool::Response(error: true) rather than a 500.
    class ToolError < StandardError; end

    # Raised by BaseTool#require_scope! when the token lacks a state-dependent
    # scope (e.g. mutating a published page without the 'publish' scope).
    class ScopeError < ToolError; end
  end
end
