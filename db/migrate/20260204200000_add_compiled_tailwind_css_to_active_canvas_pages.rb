class AddCompiledTailwindCssToActiveCanvasPages < ActiveRecord::Migration[8.0]
  def up
    add_column :active_canvas_pages, :compiled_tailwind_css, :text unless column_exists?(:active_canvas_pages, :compiled_tailwind_css)
    add_column :active_canvas_pages, :tailwind_compiled_at, :datetime unless column_exists?(:active_canvas_pages, :tailwind_compiled_at)
  end

  def down
    remove_column :active_canvas_pages, :tailwind_compiled_at if column_exists?(:active_canvas_pages, :tailwind_compiled_at)
    remove_column :active_canvas_pages, :compiled_tailwind_css if column_exists?(:active_canvas_pages, :compiled_tailwind_css)
  end
end
