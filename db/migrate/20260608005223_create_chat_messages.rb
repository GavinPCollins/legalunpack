class CreateChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_messages do |t|
      t.references :package, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role
      t.text :content

      t.timestamps
    end
  end
end
