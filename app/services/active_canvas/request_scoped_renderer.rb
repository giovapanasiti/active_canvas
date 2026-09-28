module ActiveCanvas
  # One place that knows how to render HTML against the *current request's*
  # host, protocol and mount point:
  #
  # * RequestScopedRenderer.build -- an engine renderer for out-of-request
  #   page rendering (PagePreview, CollectionItemPreview). A bare
  #   ActionController::Renderer would otherwise default to a placeholder host
  #   ("example.org").
  # * RequestScopedRenderer.rich_text_renderer -- a renderer with the HOST
  #   APP's routes for Action Text content. Action Text renders attachments
  #   through `image_tag blob.representation(...)`, which needs the Active
  #   Storage routes; those live in the host app, not in this engine, so an
  #   engine controller (which Action Text installs as the renderer for every
  #   ActionController::Base request) can't build them.
  # * RequestScopedRenderer.around(request) { ... } -- records the request's
  #   URL options (also on ActiveStorage::Current, like
  #   ActiveStorage::SetCurrent does) and installs the rich text renderer for
  #   the block. Every engine controller that can render collection rich text
  #   wraps its actions in it (public pages, admin, MCP).
  module RequestScopedRenderer
    thread_mattr_accessor :request_options

    class << self
      def around(request)
        previous_options = request_options
        previous_url_options = ActiveStorage::Current.url_options
        self.request_options = options_from(request)
        ActiveStorage::Current.url_options = { protocol: request.protocol, host: request.host, port: request.port }
        ActionText::Content.with_renderer(rich_text_renderer) { yield }
      ensure
        self.request_options = previous_options
        ActiveStorage::Current.url_options = previous_url_options
      end

      # Engine renderer for a full ActiveCanvas page render.
      def build
        options = current_options
        return ActiveCanvas::PagesController.renderer unless options

        ActiveCanvas::PagesController.renderer.new(
          http_host: options[:http_host], https: options[:https], script_name: options[:engine_script_name]
        )
      end

      # Host-app renderer for ActionText::Content (attachments).
      def rich_text_renderer
        base = host_controller.renderer
        options = current_options
        return base unless options

        base.new(http_host: options[:http_host], https: options[:https], script_name: options[:app_script_name])
      end

      # Runs the block with the rich text renderer installed, keeping any
      # request-scoped one already in place (see .around).
      def with_rich_text_renderer(&block)
        ActionText::Content.with_renderer(rich_text_renderer, &block)
      end

      private

      def host_controller
        if defined?(::ApplicationController) && ::ApplicationController < ActionController::Base
          ::ApplicationController
        else
          ActionController::Base
        end
      end

      def options_from(request)
        {
          http_host: request.host_with_port,
          https: request.ssl?,
          # Inside a mounted engine, script_name is the mount path;
          # original_script_name is the host app's own prefix.
          engine_script_name: request.script_name.to_s,
          app_script_name: (request.original_script_name || request.script_name).to_s
        }
      end

      # The request on record (see .around), else ActiveStorage::Current's
      # URL options when something else recorded them, else nil (the
      # renderer's defaults).
      def current_options
        return request_options if request_options

        url_options = ActiveStorage::Current.url_options
        return nil if url_options.blank? || url_options[:host].blank?

        https = url_options[:protocol].to_s.start_with?("https")
        default_port = https ? 443 : 80
        http_host = if url_options[:port].present? && url_options[:port].to_i != default_port
          "#{url_options[:host]}:#{url_options[:port]}"
        else
          url_options[:host]
        end

        { http_host: http_host, https: https, engine_script_name: "", app_script_name: "" }
      end
    end
  end
end
