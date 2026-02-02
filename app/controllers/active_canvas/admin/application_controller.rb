module ActiveCanvas
  module Admin
    class ApplicationController < ActionController::Base
      protect_from_forgery with: :exception
      layout "active_canvas/admin/application"
    end
  end
end
