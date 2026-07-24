class MachinesController < ApplicationController
  before_action :set_machine, only: [ :edit, :update ]

  def index
    @machines = Machine.includes(:slots).order(created_at: :desc)
  end

  def new
    @machine = Machine.new
  end

  def create
    @machine = Machine.new(machine_params)

    if @machine.save
      redirect_to machines_path, notice: "Machine successfully deployed at #{@machine.location_name}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @machine.update(machine_params)
      redirect_to machines_path, notice: "Machine at #{@machine.location_name} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_machine
    @machine = Machine.find(params[:id])
  end

  def machine_params
    # Only allow users to submit these specific fields
    params.require(:machine).permit(:location_name, :status)
  end
end
