class CreateActiveCanvasCollections < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_collections do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.json :fields, null: false, default: []
      t.timestamps
    end

    add_index :active_canvas_collections, :slug, unique: true
  end
end
