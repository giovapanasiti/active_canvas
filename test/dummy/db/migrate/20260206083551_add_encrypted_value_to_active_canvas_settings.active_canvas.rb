# This migration comes from active_canvas (originally 20260205100001)
class AddEncryptedValueToActiveCanvasSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :active_canvas_settings, :encrypted_value, :text
  end
end
