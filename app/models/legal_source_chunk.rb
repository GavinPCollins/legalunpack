require "pg_search/model"

class LegalSourceChunk < ApplicationRecord
  include PgSearch::Model

  belongs_to :legal_source
  has_many :chat_message_legal_references, dependent: :destroy

  validates :content, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :legal_source_id }

  pg_search_scope :search_by_content,
                  against: {
                    heading: "A",
                    section_label: "A",
                    content: "B"
                  },
                  associated_against: {
                    legal_source: {
                      title: "A",
                      citation: "A",
                      jurisdiction: "C",
                      publisher: "D"
                    }
                  },
                  using: {
                    tsearch: { prefix: true, normalization: 2 }
                  }
end
