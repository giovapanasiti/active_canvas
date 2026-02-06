module ActiveCanvas
  class Engine < ::Rails::Engine
    isolate_namespace ActiveCanvas

    # Clear the engine's db/migrate path to prevent duplicate migrations
    # Migrations should be installed via: rails active_canvas:install:migrations
    paths["db/migrate"] = []

    # Ensure engine assets are precompiled
    initializer "active_canvas.assets.precompile" do |app|
      app.config.assets.precompile += %w[
        active_canvas/editor.js
        active_canvas/editor.css
      ]
    end

    # Filter sensitive parameters from logs
    initializer "active_canvas.filter_parameters" do |app|
      app.config.filter_parameters += [
        :ai_openai_api_key,
        :ai_anthropic_api_key,
        :ai_openrouter_api_key,
        :http_basic_password,
        /active_canvas.*api.*key/i,
        /active_canvas.*password/i
      ]
    end

    # Warn about authentication configuration
    config.after_initialize do
      if defined?(Rails::Server) && Rails.env.production?
        unless ActiveCanvas.config.authenticate_admin.present?
          Rails.logger.warn <<~MSG
            [ActiveCanvas] WARNING: Admin authentication is not configured!
            Your admin interface will be inaccessible until you configure authentication.
            See the ActiveCanvas documentation for setup instructions.
          MSG
        end
      end
    end
  end
end
