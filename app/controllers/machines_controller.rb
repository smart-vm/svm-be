class MachinesController < ApplicationController
  def index
    @machines = Machine.includes(:slots).order(created_at: :desc)
  end
end
