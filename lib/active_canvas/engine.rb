module ActiveCanvas
  class Engine < ::Rails::Engine
    isolate_namespace ActiveCanvas

    # Prevent engine migrations from auto-running in the host app.
    # Host apps copy migrations via: rails active_canvas:install:migrations
    initializer "active_canvas.migrations", before: :append_migrations do
      config.paths["db/migrate"] = []
    end

    # Ensure engine assets are precompiled
    initializer "active_canvas.assets.precompile" do |app|
      app.config.assets.precompile += %w[
        active_canvas/editor.js
        active_canvas/editor.css
        active_canvas/editor/ac_bindings.js
        active_canvas/editor/ac_chips.js
        active_canvas/editor/directive_traits.js
        active_canvas/editor/template_validator.js
        active_canvas/editor/live_data.js
        active_canvas/admin/data_panel.js
        active_canvas/admin/field_builder.js
        active_canvas/admin/media_select_preview.js
      ]
    end

    # Lexxy (Rails 8.0/8.1 fallback path) sets config.lexxy.override_action_text_defaults
    # = true in its own Engine class body, at gem-require time -- before ANY
    # initializer runs -- which globally aliases form.rich_text_area /
    # rich_text_area_tag to Lexxy for the WHOLE host app. We want Lexxy only where
    # we explicitly call lexxy_rich_textarea_tag (the collection rich_text field
    # input), so a host app's own ActionText/Trix usage is left untouched.
    #
    # This initializer runs during the railtie-initializer boot phase, before the
    # host's own config/initializers/*.rb (loaded later, in the Finisher phase) and
    # well before Lexxy's `to_prepare` block actually reads the flag. So the host
    # can still opt in to the app-wide override by setting it back to true in its
    # own config/initializers/lexxy.rb -- that later assignment wins.
    initializer "active_canvas.lexxy_host_isolation" do |app|
      app.config.lexxy.override_action_text_defaults = false
    end

    # Filter sensitive parameters from logs
    initializer "active_canvas.filter_parameters" do |app|
      app.config.filter_parameters += [
        :ai_openai_api_key,
        :ai_anthropic_api_key,
        :ai_openrouter_api_key,
        :http_basic_password,
        /active_canvas.*api.*key/i,
        /active_canvas.*password/i,
        # MCP tool arguments: upload_media's raw file bytes, and update_ai_settings' unprefixed
        # key names (distinct from the ai_*_api_key Setting names filtered above).
        :data_base64,
        :openai_api_key,
        :anthropic_api_key,
        :openrouter_api_key
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

    # Freeze the data source registry after all after_initialize hooks have run
    # (including the host app's own after_initialize blocks that register sources)
    # so subsequent registration attempts raise loudly.
    initializer "active_canvas.freeze_data_sources", after: :finisher_hook do
      ActiveCanvas::DataSources.freeze!
    end
  end
end
