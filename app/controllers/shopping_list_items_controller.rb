class ShoppingListItemsController < ApplicationController
  def update
    item = ShoppingListItem.find(params[:id])
    item.update!(item_params)
    respond_to do |format|
      format.html { redirect_to shopping_list_path }
      format.json { render json: { id: item.id, checked: item.checked } }
    end
  end

  private

  def item_params
    params.require(:shopping_list_item).permit(:checked)
  end
end
