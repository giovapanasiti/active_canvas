module ActiveCanvas
  class ApplicationController < ActiveCanvas.config.public_parent_controller.constantize
    include ActiveCanvas::CurrentUser

    before_action :active_canvas_authenticate_public
    around_action :with_request_scoped_renderer

    private

    # Collection rich text attachments render against this request's host,
    # with the host app's routes (see RequestScopedRenderer).
    def with_request_scoped_renderer(&block)
      ActiveCanvas::RequestScopedRenderer.around(request, &block)
    end

    def active_canvas_authenticate_public
      auth = ActiveCanvas.config.authenticate_public
      return unless auth

      if auth.is_a?(Symbol)
        send(auth)
      elsif auth.respond_to?(:call)
        instance_exec(&auth)
      end
    end
  end
end
