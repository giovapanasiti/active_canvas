class AddHeaderFooterFlagsToActiveCanvasPages < ActiveRecord::Migration[8.0]
  def change
    add_column :active_canvas_pages, :show_header, :boolean, default: true, null: false
    add_column :active_canvas_pages, :show_footer, :boolean, default: true, null: false
  end
end
