class SettingsController < ApplicationController
  def show
    @setting = Setting.current
  end

  def update
    @setting = Setting.current
    if @setting.update(setting_params)
      redirect_to settings_path, notice: "Settings saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def setting_params
    params.require(:setting).permit(:flaresolverr_url)
  end
end
