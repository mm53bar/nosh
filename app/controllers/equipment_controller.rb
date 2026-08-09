class EquipmentController < ApplicationController
  def index
    @equipment = Equipment.order(owned: :desc, name: :asc)
  end

  def update
    equipment = Equipment.find(params[:id])
    equipment.update!(equipment_params)
    respond_to do |format|
      format.html { redirect_to equipment_index_path }
      format.json { render json: { id: equipment.id, owned: equipment.owned } }
    end
  end

  private

  def equipment_params
    params.require(:equipment).permit(:owned)
  end
end
