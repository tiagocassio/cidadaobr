# frozen_string_literal: true

# ACS users in team scope may register animals on households they can access via `scoped_households`.
# Write access is intentional; only read-only roles should use a stricter before_action later.
module Web
  class HouseholdAnimalsController < BaseController
    before_action :set_household, only: :create

    def create
      CommandBus.dispatch(
        Territory::Commands::RegisterHouseholdAnimal,
        household: @household,
        attributes: household_animal_params.to_h
      )
      redirect_to web_household_path(@household), notice: t("cidadaobr.household_animals.flash.created")
    rescue ActiveRecord::RecordInvalid => e
      redirect_to web_household_path(@household), alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      animal = HouseholdAnimal.joins(:household).merge(scoped_households).find(params[:id])
      household = animal.household
      CommandBus.dispatch(Territory::Commands::RemoveHouseholdAnimal, household_animal: animal)
      redirect_to web_household_path(household), notice: t("cidadaobr.household_animals.flash.removed")
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
