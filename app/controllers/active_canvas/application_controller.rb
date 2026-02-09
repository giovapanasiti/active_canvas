module ActiveCanvas
  class ApplicationController < ActionController::Base
    include ActiveCanvas::CurrentUser

    before_action :active_canvas_authenticate_public

    private

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
