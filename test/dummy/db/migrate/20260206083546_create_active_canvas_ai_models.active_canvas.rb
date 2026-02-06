class CreateActiveCanvasAiModels < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_ai_models, if_not_exists: true do |t|
      t.string :model_id, null: false
      t.string :provider, null: false
      t.string :model_type
      t.string :name
      t.string :family
      t.integer :context_window
      t.integer :max_tokens
      t.boolean :supports_vision, default: false
      t.boolean :supports_functions, default: false
      t.decimal :input_price_per_million, precision: 10, scale: 4
      t.decimal :output_price_per_million, precision: 10, scale: 4
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :active_canvas_ai_models, :model_id, unique: true, if_not_exists: true
    add_index :active_canvas_ai_models, :provider, if_not_exists: true
    add_index :active_canvas_ai_models, :model_type, if_not_exists: true
    add_index :active_canvas_ai_models, :active, if_not_exists: true
  end
end
