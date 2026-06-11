class ChatMessageLegalReference < ApplicationRecord
  belongs_to :chat_message
  belongs_to :legal_source_chunk

  validates :label, presence: true
  validates :legal_source_chunk_id, uniqueness: { scope: :chat_message_id }
end
