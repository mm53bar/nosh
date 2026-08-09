# Create-on-the-fly-by-name equipment, shared by Recipe and Technique.
# Unlike techniques (which need real authored content and are only ever
# linked to existing records via technique_ids — a has_many :through writer
# Rails already provides), a piece of equipment is just a name, so typing a
# new one into a text field is enough to create it.
module HasEquipment
  extend ActiveSupport::Concern

  def equipment_names=(names)
    self.equipment = Array(names).map { |name| Equipment.find_or_create_by(name: name.to_s.strip) }
  end

  def equipment_names
    equipment.map(&:name)
  end

  def equipment_names_text=(text)
    self.equipment_names = text.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def equipment_names_text
    equipment_names.join(", ")
  end
end
