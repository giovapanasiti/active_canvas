# This migration comes from active_canvas (originally 20260204200000)
class AddCompiledTailwindCssToActiveCanvasPages < ActiveRecord::Migration[8.0]
  def change
    add_column :active_canvas_pages, :compiled_tailwind_css, :text
    add_column :active_canvas_pages, :tailwind_compiled_at, :datetime
  end
end
