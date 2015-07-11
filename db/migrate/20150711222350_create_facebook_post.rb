class CreateFacebookPost < ActiveRecord::Migration
  def change
    create_table :facebook_posts do |t|
      t.string :graph_id, null: false # "object_id" in Facebook Graph API
      t.string :source
      t.integer :width
      t.integer :height

      t.timestamps null: false
    end
    add_index :facebook_posts, :graph_id, unique: true
  end
end
