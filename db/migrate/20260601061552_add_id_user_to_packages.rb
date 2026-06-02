class AddIdUserToPackages < ActiveRecord::Migration[8.1]
  def change
    add_column :packages, :id_user, :integer
  end
end
