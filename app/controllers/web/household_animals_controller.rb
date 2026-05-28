# frozen_string_literal: true

# ACS users in team scope may register animals on households they can access via `scoped_households`.
# Write access is intentional; only read-only roles should use a stricter before_action later.
module Web
  class HouseholdAnimalsController < BaseController
    before_action :set_household

    def create
      @household_animal = @household.household_animals.build(household_animal_params)

      if @household_animal.save
        redirect_to web_household_path(@household), notice: "Animal registrado."
      else
        redirect_to web_household_path(@household), alert: @household_animal.errors.full_messages.to_sentence
      end
    end

    def destroy
      animal = HouseholdAnimal.joins(:household).merge(scoped_households).find(params[:id])
      household = animal.household
      animal.destroy!
      redirect_to web_household_path(household), notice: "Animal removido."
    end

    private

    def set_household
      @household = scoped_households.find(params[:household_id])
    end

    def household_animal_params
      params.require(:household_animal).permit(:species, :quantity, :notes)
    end
  end
end
