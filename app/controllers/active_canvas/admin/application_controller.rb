module ActiveCanvas
  module Admin
    class ApplicationController < ActionController::Base
      protect_from_forgery with: :exception
      layout "active_canvas/admin/application"

      before_action :active_canvas_authenticate_admin

      private

      def active_canvas_authenticate_admin
        auth = ActiveCanvas.config.authenticate_admin
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
end
