class AddUsernameToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :username, :string, null: false, default: "" unless column_exists?(:users, :username)
  end

  def down
    remove_column :users, :username if column_exists?(:users, :username)
    remove_column :users, :name if column_exists?(:users, :name)
  end
end
