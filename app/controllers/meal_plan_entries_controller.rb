class MealPlanEntriesController < ApplicationController
  def index
    @start_date = parse_date(params[:start]) || Date.current.beginning_of_week
    @end_date = parse_date(params[:end]) || @start_date + 6.days

    @entries = MealPlanEntry.includes(:recipe).where(date: @start_date..@end_date).order(:date)
    @entries_by_date = @entries.group_by(&:date)
    @recipes = Recipe.order(:title)

    @slate = DinnerSlate.current(@start_date)
    @slate&.seen! if @slate&.ready?
    @ideas = @slate&.ready? ? @slate.suggestions : []
    @show_ideas = @slate.present? || (@end_date >= Date.current && LlmClient.from_env.configured?)
    @planned_on = @entries.select(&:recipe_id).to_h { |entry| [ entry.recipe_id, entry.date ] }
  end

  def create
    @entry = MealPlanEntry.new(entry_params)
    if @entry.save
      respond_to do |format|
        format.html { redirect_to meal_plan_entries_path(start: params[:redirect_start], end: params[:redirect_end]), notice: "Added to meal plan." }
        format.json { render json: entry_json(@entry), status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to meal_plan_entries_path, alert: @entry.errors.full_messages.to_sentence }
        format.json { render json: { errors: @entry.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    entry = MealPlanEntry.find(params[:id])
    entry.destroy
    respond_to do |format|
      format.html { redirect_to meal_plan_entries_path, notice: "Removed from meal plan." }
      format.json { head :no_content }
    end
  end

  private

  def parse_date(value)
    Date.parse(value) if value.present?
  rescue ArgumentError
    nil
  end

  def entry_params
    params.require(:meal_plan_entry).permit(:date, :recipe_id, :title, :servings, :notes)
  end

  def entry_json(entry)
    { id: entry.id, date: entry.date, recipe_id: entry.recipe_id, recipe_title: entry.recipe&.title, title: entry.name,
      servings: entry.servings, notes: entry.notes }
  end
end
