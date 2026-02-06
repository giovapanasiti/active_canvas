# This migration comes from active_canvas (originally 20260202000002)
class CreateActiveCanvasPages < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_pages do |t|
      t.string :title, null: false
      t.string :slug
      t.text :content
      t.references :page_type, null: false, foreign_key: { to_table: :active_canvas_page_types }
      t.boolean :published, default: false, null: false

      t.timestamps
    end

    add_index :active_canvas_pages, :slug, unique: true
  end
end
