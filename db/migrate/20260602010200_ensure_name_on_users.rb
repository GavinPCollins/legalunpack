class EnsureNameOnUsers < ActiveRecord::Migration[8.1]
  def up
    if column_exists?(:users, :user_name) && !column_exists?(:users, :name)
      rename_column :users, :user_name, :name
    elsif !column_exists?(:users, :name)
      add_column :users, :name, :string
    end
  end

  def down
    remove_column :users, :name if column_exists?(:users, :name)
  end
end
