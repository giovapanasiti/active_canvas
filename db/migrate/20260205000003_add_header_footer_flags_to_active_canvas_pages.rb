class AddHeaderFooterFlagsToActiveCanvasPages < ActiveRecord::Migration[8.0]
  def up
    add_column :active_canvas_pages, :show_header, :boolean, default: true, null: false unless column_exists?(:active_canvas_pages, :show_header)
    add_column :active_canvas_pages, :show_footer, :boolean, default: true, null: false unless column_exists?(:active_canvas_pages, :show_footer)
  end

  def down
    remove_column :active_canvas_pages, :show_footer if column_exists?(:active_canvas_pages, :show_footer)
    remove_column :active_canvas_pages, :show_header if column_exists?(:active_canvas_pages, :show_header)
  end
end
