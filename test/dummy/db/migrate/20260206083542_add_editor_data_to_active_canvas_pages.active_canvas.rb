class AddEditorDataToActiveCanvasPages < ActiveRecord::Migration[7.0]
  def up
    add_column :active_canvas_pages, :content_css, :text unless column_exists?(:active_canvas_pages, :content_css)
    add_column :active_canvas_pages, :content_components, :text unless column_exists?(:active_canvas_pages, :content_components)
  end

  def down
    remove_column :active_canvas_pages, :content_components if column_exists?(:active_canvas_pages, :content_components)
    remove_column :active_canvas_pages, :content_css if column_exists?(:active_canvas_pages, :content_css)
  end
end
