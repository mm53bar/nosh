class TechniquesController < ApplicationController
  before_action :set_technique, only: [ :show, :edit, :update, :destroy ]

  def index
    @techniques = Technique.includes(:equipment).order(:title)
  end

  def show
  end

  def new
    @technique = Technique.new
  end

  def create
    @technique = Technique.new(technique_params)
    if @technique.save
      respond_to do |format|
        format.html { redirect_to @technique, notice: "Technique added." }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @technique.errors }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @technique.update(technique_params)
      respond_to do |format|
        format.html { redirect_to @technique, notice: "Technique updated." }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @technique.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @technique.destroy
    respond_to do |format|
      format.html { redirect_to techniques_path, notice: "Technique deleted." }
      format.json { head :no_content }
    end
  end

  private

  def set_technique
    @technique = Technique.find(params[:id])
  end

  def technique_params
    params.require(:technique).permit(:title, :body, :equipment_names_text, equipment_names: [])
  end
end
