class ShoppingListItemsController < ApplicationController
  def update
    item = ShoppingListItem.find(params[:id])
    item.update!(item_params)
    respond_to do |format|
      format.html { redirect_to shopping_list_path }
      format.json { render json: { id: item.id, checked: item.checked, category: item.category } }
    end
  end

  # Bulk category assignment, e.g. after sorting the whole list into aisles
  # at once. Mirrors the old app's PATCH /api/shopping-list/categories.
  def bulk_update
    ShoppingListItem.transaction do
      params.require(:updates).each { |update| ShoppingListItem.find(update[:id]).update!(category: update[:category]) }
    end
    head :no_content
  end

  private

  def item_params
    params.require(:shopping_list_item).permit(:checked, :category)
  end
end
