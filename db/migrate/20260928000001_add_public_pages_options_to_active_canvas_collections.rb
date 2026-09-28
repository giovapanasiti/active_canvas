class AddPublicPagesOptionsToActiveCanvasCollections < ActiveRecord::Migration[8.0]
  def change
    add_column :active_canvas_collections, :has_pages, :boolean, null: false, default: false
    add_column :active_canvas_collections, :per_page, :integer, null: false, default: 12
    add_column :active_canvas_collections, :show_in_sidebar, :boolean, null: false, default: false
    add_column :active_canvas_collections, :title_field, :string
    add_column :active_canvas_collections, :description_field, :string
    add_column :active_canvas_collections, :image_field, :string

    # Before this, a blank slug could be stored as ''; the unique index only
    # skips NULLs, so two '' slugs in one collection would break it.
    reversible do |dir|
      dir.up { execute "UPDATE active_canvas_collection_items SET slug = NULL WHERE slug = ''" }
    end

    add_index :active_canvas_collection_items, [ :collection_id, :slug ], unique: true,
      where: "slug IS NOT NULL", name: "index_ac_collection_items_on_collection_id_and_slug"
  end
end
