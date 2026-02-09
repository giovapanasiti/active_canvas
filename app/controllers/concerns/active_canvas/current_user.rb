module ActiveCanvas
  module CurrentUser
    extend ActiveSupport::Concern

    private

    def active_canvas_current_user
      method_name = ActiveCanvas.config.current_user_method
      respond_to?(method_name, true) ? send(method_name) : nil
    end
  end
end
