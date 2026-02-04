module ActiveCanvas
  class ApplicationController < ActionController::Base
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

    def active_canvas_current_user
      method_name = ActiveCanvas.config.current_user_method
      respond_to?(method_name, true) ? send(method_name) : nil
    end
  end
end
