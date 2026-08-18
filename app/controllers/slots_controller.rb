class SlotsController < ApplicationController
  before_action :set_slot, only: [:edit, :update]

  def new
    @machine = Machine.find(params[:machine_id])
    @slot = @machine.slots.new
  end

  def create
    @machine = Machine.find(params[:slot][:machine_id])
    @slot = @machine.slots.new(slot_params)

    if @slot.save
      redirect_to machine_path(@machine), notice: "Slot ##{@slot.slot_number} was successfully added to this machine."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @slot.update(slot_params)
      redirect_to machine_path(@slot.machine), notice: "Slot #{@slot.slot_number} was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_slot
    @slot = Slot.find(params[:id])
  end

  def slot_params
    params.require(:slot).permit(:machine_id, :product_id, :slot_number, :current_stock, :max_capacity, :status)
  end
end