class CreateActiveCanvasSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_settings, if_not_exists: true do |t|
      t.string :key, null: false
      t.text :value

      t.timestamps
    end

    add_index :active_canvas_settings, :key, unique: true, if_not_exists: true
  end
end
