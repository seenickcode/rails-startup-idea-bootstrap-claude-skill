class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :magic_link_token
      t.datetime :magic_link_expires_at
      t.string :session_token
      t.boolean :newsletter, null: false, default: false
      t.datetime :purchased_at
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :magic_link_token, unique: true
  end
end
