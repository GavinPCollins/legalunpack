class RenameUserNameToName < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :user_name, :name if column_exists?(:users, :user_name)
  end
end
