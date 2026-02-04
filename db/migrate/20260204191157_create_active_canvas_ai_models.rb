class CreateActiveCanvasAiModels < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_ai_models do |t|
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

    add_index :active_canvas_ai_models, :model_id, unique: true
    add_index :active_canvas_ai_models, :provider
    add_index :active_canvas_ai_models, :model_type
    add_index :active_canvas_ai_models, :active
  end
end
