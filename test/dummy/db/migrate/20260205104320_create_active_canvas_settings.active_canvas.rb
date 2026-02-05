# This migration comes from active_canvas (originally 20260202000003)
class CreateActiveCanvasSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_settings do |t|
      t.string :key, null: false
      t.text :value

      t.timestamps
    end

    add_index :active_canvas_settings, :key, unique: true
  end
end
