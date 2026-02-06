class AddEncryptedValueToActiveCanvasSettings < ActiveRecord::Migration[7.1]
  def up
    add_column :active_canvas_settings, :encrypted_value, :text unless column_exists?(:active_canvas_settings, :encrypted_value)
  end

  def down
    remove_column :active_canvas_settings, :encrypted_value if column_exists?(:active_canvas_settings, :encrypted_value)
  end
end
