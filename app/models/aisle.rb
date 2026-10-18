class Aisle < ApplicationRecord
  has_many :staples, -> { order(:position, :name) }, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  before_create { self.position = (Aisle.maximum(:position) || 0) + 1 if position.to_i.zero? }
end
