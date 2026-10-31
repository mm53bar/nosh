class ShoppingListsController < ApplicationController
  def show
    load_list
  end

  def generate
    ShoppingListBuilder.generate(start_date: Date.parse(params[:start_date]), end_date: Date.parse(params[:end_date]))
    load_list
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

  private

  def load_list
    @aisles = Aisle.order(:position).includes(staples: :shopping_list_items)
    @write_ins = WriteIn.open
    @items = ShoppingListItem.this_week.order(:name)
  end
end
