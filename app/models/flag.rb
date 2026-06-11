class Flag < ApplicationRecord
  LEVELS = %w[low medium high].freeze
  CATEGORIES = %w[
    deadline
    missing_information
    negotiation_point
    legal_review
    document_check
    commercial_decision
    unclear_term
  ].freeze
  EVIDENCE_BASES = %w[legal_reference commercial_risk legal_review].freeze

  belongs_to :clause
  has_many :flag_legal_references, dependent: :destroy
  has_many :legal_source_chunks, through: :flag_legal_references

  validates :name, presence: true
  validates :level, inclusion: { in: LEVELS }, allow_blank: true
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :evidence_basis, inclusion: { in: EVIDENCE_BASES }, allow_blank: true

  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }

  before_save :set_resolved_at

  private

  def set_resolved_at
    return unless will_save_change_to_resolved?

    self.resolved_at = resolved? ? Time.current : nil
    self.resolution_note = nil unless resolved?
  end
end
