class AddContentJsToActiveCanvasPages < ActiveRecord::Migration[7.0]
  def up
    add_column :active_canvas_pages, :content_js, :text unless column_exists?(:active_canvas_pages, :content_js)
  end

  def down
    remove_column :active_canvas_pages, :content_js if column_exists?(:active_canvas_pages, :content_js)
  end
end
