class AddBindingsToActiveCanvasPageVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :active_canvas_page_versions, :bindings_before, :json
    add_column :active_canvas_page_versions, :bindings_after,  :json
  end
end
