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

  # "Lock it in" — rebuild the list from the meal plan when given a range, then
  # push it to Home Assistant in the background. Deliberately one endpoint for
  # both callers: the button in nosh, and Casey finalising a week in Slack.
  def publish
    if params[:start_date].present? && params[:end_date].present?
      ShoppingListBuilder.generate(start_date: Date.parse(params[:start_date]), end_date: Date.parse(params[:end_date]))
    end

    ShoppingListPushJob.perform_later

    respond_to do |format|
      format.html { redirect_to shopping_list_path, notice: "Sending the shopping list to Home Assistant." }
      format.json { head :accepted }
    end
  end

  # What publishing would add, without writing anything.
  def publish_preview
    @preview = ShoppingListPublisher.new.preview

    respond_to do |format|
      format.html { redirect_to shopping_list_path, notice: @preview.summary }
      format.json { render json: { configured: @preview.configured?, added: @preview.added, skipped: @preview.skipped } }
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
