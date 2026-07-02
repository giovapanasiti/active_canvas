class CreateActiveCanvasCollectionItems < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_collection_items do |t|
      t.references :collection, null: false, index: false,
        foreign_key: { to_table: :active_canvas_collections }
      t.json :data, null: false, default: {}
      t.json :draft_data, null: false, default: {}
      t.string :status, null: false, default: "draft"
      t.string :slug
      t.datetime :published_at
      t.timestamps
    end

    add_index :active_canvas_collection_items, [ :collection_id, :status ]
  end
end
