# Something typed into the shopping list that isn't a staple — the blank lines
# at the bottom of the old pocket lists. Gone once bought, but remembered, so a
# name that keeps coming back can be offered a tab of its own.
class WriteIn < ApplicationRecord
  PROMOTE_AT = 3

  validates :name, presence: true

  before_validation { self.name = name.to_s.squish }

  scope :open, -> { where(bought_at: nil).order(:created_at) }

  def key = StapleMatcher.key(name)

  def times_written = WriteIn.all.count { |write_in| write_in.key == key }

  def promotable? = times_written >= PROMOTE_AT

  def bought? = bought_at.present?
end
