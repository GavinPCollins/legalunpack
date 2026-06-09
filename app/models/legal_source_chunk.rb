require "pg_search/model"

class LegalSourceChunk < ApplicationRecord
  include PgSearch::Model

  belongs_to :legal_source

  validates :content, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :position, uniqueness: { scope: :legal_source_id }

  pg_search_scope :search_by_content,
                  against: [ :heading, :section_label, :content ],
                  associated_against: {
                    legal_source: [ :title, :citation, :jurisdiction, :publisher ]
                  },
                  using: {
                    tsearch: { prefix: true }
                  }
end
