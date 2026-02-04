module ActiveCanvas
  class Engine < ::Rails::Engine
    isolate_namespace ActiveCanvas

    # Ensure engine assets are precompiled
    initializer "active_canvas.assets.precompile" do |app|
      app.config.assets.precompile += %w[
        active_canvas/editor.js
        active_canvas/editor.css
      ]
    end
  end
end
