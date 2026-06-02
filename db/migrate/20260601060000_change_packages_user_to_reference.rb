class ChangePackagesUserToReference < ActiveRecord::Migration[8.1]
  def change
    # remove the incorrectly named integer column
    remove_column :packages, :id_user, :integer

    # add a proper reference and foreign key to users
    add_reference :packages, :user, foreign_key: true, index: true
  end
end
