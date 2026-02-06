class CreateActiveCanvasPartials < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_partials, if_not_exists: true do |t|
      t.string :name, null: false
      t.string :partial_type, null: false # "header" or "footer"
      t.text :content
      t.text :content_css
      t.text :content_js
      t.text :content_components
      t.text :compiled_css
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :active_canvas_partials, :partial_type, unique: true, if_not_exists: true
  end
end
