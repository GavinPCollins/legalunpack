class AddNameToPackages < ActiveRecord::Migration[8.1]
  def change
    add_column :packages, :name, :string
  end
end
