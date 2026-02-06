class CreateActiveCanvasPages < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_pages, if_not_exists: true do |t|
      t.string :title, null: false
      t.string :slug
      t.text :content
      t.references :page_type, null: false, foreign_key: { to_table: :active_canvas_page_types }
      t.boolean :published, default: false, null: false

      t.timestamps
    end

    add_index :active_canvas_pages, :slug, unique: true, if_not_exists: true
  end
end
