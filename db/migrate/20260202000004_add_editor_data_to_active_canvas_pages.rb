class AddEditorDataToActiveCanvasPages < ActiveRecord::Migration[7.0]
  def change
    add_column :active_canvas_pages, :content_css, :text
    add_column :active_canvas_pages, :content_components, :text
  end
end
