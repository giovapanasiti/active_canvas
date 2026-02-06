class RemoveSupportsVisionFromActiveCanvasAiModels < ActiveRecord::Migration[8.0]
  def up
    remove_column :active_canvas_ai_models, :supports_vision if column_exists?(:active_canvas_ai_models, :supports_vision)
  end

  def down
    unless column_exists?(:active_canvas_ai_models, :supports_vision)
      add_column :active_canvas_ai_models, :supports_vision, :boolean, default: false

      execute <<~SQL
        UPDATE active_canvas_ai_models
        SET supports_vision = #{quoted_true}
        WHERE input_modalities LIKE '%"image"%'
      SQL
    end
  end

  private

  def quoted_true
    ActiveRecord::Base.connection.quoted_true
  end
end
