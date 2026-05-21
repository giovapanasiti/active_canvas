class AddTemplateEnabledAndBindingsToActiveCanvasPages < ActiveRecord::Migration[8.0]
  def change
    add_column :active_canvas_pages, :template_enabled, :boolean, default: false, null: false
    add_column :active_canvas_pages, :bindings,         :json,    default: {},     null: false
  end
end
