class CreateActiveCanvasPageTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_page_types do |t|
      t.string :name, null: false
      t.string :key, null: false

      t.timestamps
    end

    add_index :active_canvas_page_types, :key, unique: true
  end
end
