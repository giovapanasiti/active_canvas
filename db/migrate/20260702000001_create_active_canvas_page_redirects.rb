class CreateActiveCanvasPageRedirects < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_page_redirects do |t|
      t.string :from_slug, null: false
      t.references :page, null: false, foreign_key: { to_table: :active_canvas_pages }
      t.timestamps
    end

    add_index :active_canvas_page_redirects, :from_slug, unique: true
  end
end
