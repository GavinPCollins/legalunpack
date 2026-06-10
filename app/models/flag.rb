class Flag < ApplicationRecord
  LEVELS = %w[low medium high].freeze

  belongs_to :clause

  validates :name, presence: true
  validates :level, inclusion: { in: LEVELS }, allow_blank: true

  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }

  before_save :set_resolved_at

  private

  def set_resolved_at
    return unless will_save_change_to_resolved?

    self.resolved_at = resolved? ? Time.current : nil
  end
end
