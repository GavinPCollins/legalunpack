class Clause < ApplicationRecord
  RISK_LEVELS = %w[low medium high].freeze

  belongs_to :package
  belongs_to :doc_file, optional: true
  has_many :flags, dependent: :destroy

  validates :risk_level, inclusion: { in: RISK_LEVELS }, allow_blank: true
end
