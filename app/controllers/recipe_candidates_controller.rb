class RecipeCandidatesController < ApplicationController
  before_action :set_candidate, only: [ :show, :accept, :discard ]

  def index
    @candidates = RecipeCandidate.awaiting_review
    @queued_count = RecipeCandidate.queued.count
  end

  # The review: the recipe form, filled from the proposal.
  def show
    @recipe = @candidate.build_recipe
  end

  def accept
    @recipe = Recipe.new(recipe_params)
    if @candidate.accept(@recipe)
      redirect_to @recipe, notice: "Added \"#{@recipe.title}\"."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def discard
    @candidate.discarded!
    redirect_to next_review_path, notice: "Discarded \"#{@candidate.title}\"."
  end

  def scan
    YoutubeImportJob.perform_later
    redirect_to recipe_candidates_path, notice: "Checking for new videos. Anything found shows up here in a minute or two."
  end

  private

  def set_candidate
    @candidate = RecipeCandidate.find(params[:id])
  end

  def next_review_path
    (next_candidate = RecipeCandidate.awaiting_review.first) ? recipe_candidate_path(next_candidate) : recipe_candidates_path
  end

  def recipe_params
    params.require(:recipe).permit(
      :title, :source_url, :description, :servings, :cuisine, :meal_type,
      :prep_time_minutes, :total_time_minutes, :notes, :rating, :image,
      :tag_names_text, :equipment_names_text, technique_ids: [],
      ingredients_attributes: [ :amount, :amount_max, :unit, :name, :note, :original_text, :position, :_destroy ],
      steps_attributes: [ :instruction, :position, :_destroy ]
    )
  end
end
