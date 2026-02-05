class CreateActiveCanvasPageVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_page_versions do |t|
      t.references :page, null: false, foreign_key: { to_table: :active_canvas_pages }
      t.integer :version_number, null: false
      t.text :content_before
      t.text :content_after
      t.text :content_diff
      t.text :css_before
      t.text :css_after
      t.string :change_summary
      t.string :changed_by
      t.integer :content_size_before
      t.integer :content_size_after

      t.timestamps
    end

    add_index :active_canvas_page_versions, [:page_id, :version_number], unique: true
    add_index :active_canvas_page_versions, :created_at
  end
end
