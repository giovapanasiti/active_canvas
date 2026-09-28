class AddCollectionToActiveCanvasPages < ActiveRecord::Migration[8.0]
  def change
    add_reference :active_canvas_pages, :collection, null: true, index: true,
      foreign_key: { to_table: :active_canvas_collections }
    add_column :active_canvas_pages, :collection_role, :string

    add_index :active_canvas_pages, [ :collection_id, :collection_role ], unique: true,
      name: "index_active_canvas_pages_on_collection_id_and_role"
  end
end
