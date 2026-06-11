class FlagLegalReference < ApplicationRecord
  belongs_to :flag
  belongs_to :legal_source_chunk

  validates :legal_source_chunk_id, uniqueness: { scope: :flag_id }
end
