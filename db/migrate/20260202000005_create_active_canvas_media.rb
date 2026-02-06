class CreateActiveCanvasMedia < ActiveRecord::Migration[7.0]
  def change
    create_table :active_canvas_media, if_not_exists: true do |t|
      t.string :filename, null: false
      t.string :content_type
      t.integer :byte_size
      t.text :metadata

      t.timestamps
    end

    add_index :active_canvas_media, :content_type, if_not_exists: true
    add_index :active_canvas_media, :created_at, if_not_exists: true
  end
end
