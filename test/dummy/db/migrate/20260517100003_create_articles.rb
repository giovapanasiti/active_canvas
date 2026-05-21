class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title, null: false
      t.string :slug
      t.text :excerpt
      t.boolean :published, default: false
      t.string :category
      t.datetime :published_at
      t.timestamps
    end
  end
end
