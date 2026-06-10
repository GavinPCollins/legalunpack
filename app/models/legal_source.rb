class LegalSource < ApplicationRecord
  SOURCE_TYPES = %w[act regulation regulator_guidance case internal_note other].freeze
  AUTHORITY_LEVELS = %w[legislation regulation guidance case_law internal_note other].freeze
  SOURCE_FORMATS = %w[html pdf txt].freeze

  has_one_attached :source_file
  has_many :legal_source_chunks, dependent: :destroy

  before_validation :normalize_blank_source_url

  validates :title, :jurisdiction, :source_type, :authority_level, :source_format, presence: true
  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :authority_level, inclusion: { in: AUTHORITY_LEVELS }
  validates :source_format, inclusion: { in: SOURCE_FORMATS }
  validates :source_url, uniqueness: true, allow_blank: true
  validate :source_location_present

  scope :recent_first, -> { order(created_at: :desc, title: :asc) }

  def source_name
    source_file.attached? ? source_file.filename.to_s : source_url
  end

  def imported?
    imported_at.present?
  end

  private

  def normalize_blank_source_url
    self.source_url = nil if source_url.blank?
  end

  def source_location_present
    return if source_url.present? || source_file.attached?

    errors.add(:base, "Add a source URL or upload a source file")
  end
end
