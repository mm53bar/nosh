class Technique < ApplicationRecord
  include HasEquipment

  has_many :technique_equipments, dependent: :destroy
  has_many :equipment, through: :technique_equipments
  has_many :recipe_techniques, dependent: :destroy
  has_many :recipes, through: :recipe_techniques

  validates :title, presence: true, uniqueness: true
end
