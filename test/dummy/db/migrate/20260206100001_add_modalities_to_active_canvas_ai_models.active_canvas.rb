class AddModalitiesToActiveCanvasAiModels < ActiveRecord::Migration[8.0]
  def up
    add_column :active_canvas_ai_models, :input_modalities, :text unless column_exists?(:active_canvas_ai_models, :input_modalities)
    add_column :active_canvas_ai_models, :output_modalities, :text unless column_exists?(:active_canvas_ai_models, :output_modalities)

    # Backfill from model_type + supports_vision (only if supports_vision still exists)
    if column_exists?(:active_canvas_ai_models, :supports_vision)
      execute <<~SQL
        UPDATE active_canvas_ai_models
        SET input_modalities  = CASE
              WHEN model_type = 'chat' AND supports_vision = #{quoted_true} THEN '["text","image"]'
              ELSE '["text"]'
            END,
            output_modalities = CASE
              WHEN model_type = 'image'     THEN '["image"]'
              WHEN model_type = 'embedding' THEN '["embedding"]'
              WHEN model_type = 'audio'     THEN '["audio"]'
              ELSE '["text"]'
            END
        WHERE input_modalities IS NULL
      SQL
    end
  end

  def down
    remove_column :active_canvas_ai_models, :input_modalities if column_exists?(:active_canvas_ai_models, :input_modalities)
    remove_column :active_canvas_ai_models, :output_modalities if column_exists?(:active_canvas_ai_models, :output_modalities)
  end

  private

  def quoted_true
    ActiveRecord::Base.connection.quoted_true
  end
end
