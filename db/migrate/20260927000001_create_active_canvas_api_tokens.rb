class CreateActiveCanvasApiTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :active_canvas_api_tokens do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.json :scopes, null: false, default: [ "read" ]
      t.datetime :last_used_at
      t.datetime :expires_at
      t.datetime :revoked_at
      t.string :created_by
      t.timestamps
    end
    add_index :active_canvas_api_tokens, :token_digest, unique: true
  end
end
