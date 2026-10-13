class AdvertisementsController < ApplicationController
  before_action :set_advertisement, only: [ :edit, :update, :destroy ]

  def index
    @advertisements = Advertisement.includes(:machines, media_attachment: :blob).order(:position, :id)
  end

  def new
    @advertisement = Advertisement.new(duration_seconds: 8, active: true, placements: Advertisement::PLACEMENTS.keys)
  end

  def create
    @advertisement = Advertisement.new(advertisement_params)

    if @advertisement.save
      redirect_to advertisements_path, notice: "Advertisement \"#{@advertisement.title}\" was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @advertisement.update(advertisement_params)
      redirect_to advertisements_path, notice: "Advertisement \"#{@advertisement.title}\" was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @advertisement.destroy!
    redirect_to advertisements_path, notice: "Advertisement \"#{@advertisement.title}\" was deleted."
  end

  private

  def set_advertisement
    @advertisement = Advertisement.find(params[:id])
  end

  def advertisement_params
    params.require(:advertisement).permit(:title, :media, :duration_seconds, :starts_at, :ends_at, :active, :position,
                                          placements: [], machine_ids: [])
  end
end
