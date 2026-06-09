require "pg_search/model"

class LegalSource < ApplicationRecord
  include PgSearch::Model

  SOURCE_TYPES = %w[act regulation regulator_guidance case internal_note other].freeze
  AUTHORITY_LEVELS = %w[legislation regulation guidance case_law internal_note other].freeze
  SOURCE_FORMATS = %w[html pdf txt].freeze

  has_many :legal_source_chunks, dependent: :destroy

  validates :title, :jurisdiction, :source_type, :authority_level, :source_url, :source_format, presence: true
  validates :source_url, uniqueness: true
  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :authority_level, inclusion: { in: AUTHORITY_LEVELS }
  validates :source_format, inclusion: { in: SOURCE_FORMATS }

  pg_search_scope :search_by_title_and_text,
                  against: [ :title, :citation, :raw_text ],
                  associated_against: {
                    legal_source_chunks: [ :heading, :section_label, :content ]
                  },
                  using: {
                    tsearch: { prefix: true }
                  }
end
