class Equipment < ApplicationRecord
  has_many :recipe_equipments, dependent: :destroy
  has_many :recipes, through: :recipe_equipments
  has_many :technique_equipments, dependent: :destroy
  has_many :techniques, through: :technique_equipments

  validates :name, presence: true, uniqueness: true
end
