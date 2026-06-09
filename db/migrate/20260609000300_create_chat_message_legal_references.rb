class CreateChatMessageLegalReferences < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_message_legal_references do |t|
      t.references :chat_message, null: false, foreign_key: true
      t.references :legal_source_chunk, null: false, foreign_key: true
      t.string :label, null: false

      t.timestamps
    end

    add_index :chat_message_legal_references,
              [ :chat_message_id, :legal_source_chunk_id ],
              unique: true,
              name: "index_chat_legal_refs_on_message_and_chunk"
  end
end
