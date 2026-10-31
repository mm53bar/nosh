class SettingsController < ApplicationController
  def update
    Setting.current.update!(params.require(:setting).permit(:dinner_slate_notes))

    respond_to do |format|
      format.html { redirect_back_or_to meal_plan_entries_path, notice: "Saved." }
      format.json { render json: Setting.current.slice(:dinner_slate_notes) }
    end
  end
end
