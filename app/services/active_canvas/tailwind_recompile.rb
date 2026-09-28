module ActiveCanvas
  # Queues every page with content for a Tailwind recompile. Used by
  # Admin::SettingsController#recompile_tailwind and the `recompile_tailwind`
  # MCP tool.
  class TailwindRecompile
    class Unavailable < StandardError; end

    def self.call
      new.call
    end

    def call
      raise Unavailable, "tailwindcss-ruby gem is not installed." unless ActiveCanvas::TailwindCompiler.available?
      raise Unavailable, "Tailwind is not the selected CSS framework." unless Setting.css_framework == "tailwind"

      pages = Page.where.not(content: [ nil, "" ])
      pages.find_each { |page| CompileTailwindJob.perform_later(page.id) }

      { enqueued: pages.count }
    end
  end
end
