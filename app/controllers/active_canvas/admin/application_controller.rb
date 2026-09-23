module ActiveCanvas
  module Admin
    class ApplicationController < ActiveCanvas.config.admin_parent_controller.constantize
      include ActiveCanvas::CurrentUser

      protect_from_forgery with: :exception
      layout "active_canvas/admin/application"

      before_action :enforce_authentication_configured
      before_action :active_canvas_authenticate_admin
      before_action :set_current_editor

      private

      # A readable label for version history: a name or email when the host's
      # user object has one, otherwise its to_s.
      def set_current_editor
        user = active_canvas_current_user
        ActiveCanvas::Current.editor = user && [ user.try(:name), user.try(:email), user.to_s ].map(&:presence).compact.first
      end

      def enforce_authentication_configured
        # Skip if inheriting from a custom parent controller (assumes parent handles auth)
        return if ActiveCanvas.config.admin_parent_controller != "ActionController::Base"

        ActiveCanvas.config.enforce_authentication!
      rescue SecurityError => e
        Rails.logger.error(e.message)
        render plain: "Admin authentication not configured. Check server logs.", status: :forbidden
      end

      def active_canvas_authenticate_admin
        # Skip if inheriting from a custom parent controller (assumes parent handles auth)
        return if ActiveCanvas.config.admin_parent_controller != "ActionController::Base"

        auth = ActiveCanvas.config.authenticate_admin
        return unless auth

        if auth == :http_basic_auth
          authenticate_with_http_basic_auth
        elsif auth.is_a?(Symbol)
          send(auth)
        elsif auth.respond_to?(:call)
          instance_exec(&auth)
        end
      end

      def authenticate_with_http_basic_auth
        config = ActiveCanvas.config

        unless config.http_basic_auth_configured?
          Rails.logger.error "[ActiveCanvas] HTTP Basic Auth selected but credentials not configured"
          render plain: "Authentication misconfigured", status: :forbidden
          return
        end

        authenticate_or_request_with_http_basic("ActiveCanvas Admin") do |username, password|
          ActiveSupport::SecurityUtils.secure_compare(username, config.http_basic_user) &
            ActiveSupport::SecurityUtils.secure_compare(password, config.http_basic_password)
        end
      end
    end
  end
end
