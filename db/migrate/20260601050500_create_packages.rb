class CreatePackages < ActiveRecord::Migration[8.1]
  def change
    create_table :packages do |t|
      t.integer :id_user
      t.string :category
      t.text :overview
      t.string :status

      t.timestamps
    end
  end
end
