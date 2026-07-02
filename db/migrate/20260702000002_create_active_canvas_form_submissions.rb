class CreateActiveCanvasFormSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_form_submissions do |t|
      t.references :page, null: false, index: false, foreign_key: { to_table: :active_canvas_pages }
      t.string :form_key, null: false
      t.json :data, null: false, default: {}
      t.string :ip
      t.string :user_agent
      t.timestamps
    end

    add_index :active_canvas_form_submissions, [ :page_id, :form_key ]
  end
end
