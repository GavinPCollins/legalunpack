class DocFile < ApplicationRecord
  belongs_to :package
  has_one_attached :file

  validates :file, presence: true
end
