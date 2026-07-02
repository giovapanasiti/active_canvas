class CreateActiveCanvasCollectionItemVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_collection_item_versions do |t|
      t.references :collection_item, null: false, index: false,
        foreign_key: { to_table: :active_canvas_collection_items }
      t.integer :version_number, null: false
      t.json :data, null: false, default: {}
      t.string :changed_by
      t.string :change_summary
      t.timestamps
    end

    add_index :active_canvas_collection_item_versions,
      [ :collection_item_id, :version_number ], unique: true,
      name: "idx_ac_collection_item_versions_on_item_and_number"
  end
end
