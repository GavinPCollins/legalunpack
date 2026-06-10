class ChatMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :package
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true
end
