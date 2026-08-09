class ShoppingListsController < ApplicationController
  def show
    @items = ShoppingListItem.order(:category, :name)
  end

  def generate
    ShoppingListBuilder.generate(start_date: Date.parse(params[:start_date]), end_date: Date.parse(params[:end_date]))
    @items = ShoppingListItem.order(:category, :name)
    respond_to do |format|
      format.html { redirect_to shopping_list_path, notice: "Shopping list regenerated." }
      format.json { render :show }
    end
  end

  def destroy
    ShoppingListItem.delete_all
    respond_to do |format|
      format.html { redirect_to shopping_list_path, notice: "Shopping list cleared." }
      format.json { head :no_content }
    end
  end
end
