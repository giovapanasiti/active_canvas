# This migration comes from active_canvas (originally 20260202000006)
class AddContentJsToActiveCanvasPages < ActiveRecord::Migration[7.0]
  def change
    add_column :active_canvas_pages, :content_js, :text
  end
end
