class ChatMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :package
  belongs_to :user
  has_many :chat_message_legal_references, dependent: :destroy
  has_many :legal_source_chunks, through: :chat_message_legal_references

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true
end
