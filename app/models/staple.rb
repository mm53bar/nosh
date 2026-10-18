# A tab on the shopping board: something the household keeps in stock, flipped
# on when it runs out and off when it's bought. See
# docs/adr/20261018-shopping-list-is-a-staples-board.md.
class Staple < ApplicationRecord
  belongs_to :aisle
  has_many :shopping_list_items, dependent: :nullify

  attribute :aliases, :json, default: -> { [] }

  validates :name, presence: true
  validate :keys_are_unclaimed
  validate :name_is_not_a_group

  before_validation :tidy
  before_create { self.position = (aisle.staples.maximum(:position) || 0) + 1 if position.to_i.zero? }

  scope :needed, -> { where(needed: true) }

  # Everything this tab answers to, normalised the way StapleMatcher reads input.
  def keys = ([ name ] + aliases).map { |text| StapleMatcher.key(text) }.uniq

  def aliases_text = aliases.join(", ")

  def aliases_text=(text)
    self.aliases = text.to_s.split(",")
  end

  def aisle_name=(name)
    self.aisle = Aisle.find_or_create_by!(name: name.to_s.strip)
  end

  private

  def tidy
    self.name = name.to_s.squish.downcase
    self.group_name = group_name.to_s.squish.downcase.presence
    self.aliases = Array(aliases).map { |text| text.to_s.squish.downcase }.compact_blank.uniq
  end

  # Two tabs answering to the same word would make "add X" ambiguous, and the
  # matcher would silently pick whichever loaded first.
  def keys_are_unclaimed
    others = Staple.where.not(id: id).flat_map { |staple| staple.keys.map { |key| [ key, staple.name ] } }.to_h
    keys.each do |key|
      errors.add(:base, "\"#{key}\" already belongs to #{others[key]}") if others.key?(key)
    end
  end

  # A group word names several different things to buy, so it can never be a
  # tab of its own — "cheese" has to be a particular cheese.
  def name_is_not_a_group
    groups = Staple.where.not(group_name: nil).pluck(:group_name).map { |group| StapleMatcher.key(group) }
    groups << StapleMatcher.key(group_name) if group_name
    clash = keys & groups
    errors.add(:base, "\"#{clash.first}\" is a group of tabs, not a tab") if clash.any?
  end
end
