# frozen_string_literal: true

module Web
  class HouseholdMembersController < BaseController
    before_action :require_facility_or_municipality_write!
    before_action :set_household, only: %i[create]
    before_action :set_citizen_from_params, only: %i[create]

    def create
      citizen = @citizen || scoped_citizens.find(household_member_params[:citizen_id])
      member = CommandBus.dispatch(
        Territory::Commands::LinkCitizenToHousehold,
        household: @household,
        citizen: citizen,
        family_reference: ActiveModel::Type::Boolean.new.cast(household_member_params[:family_reference]) || false
      ).household_member

      redirect_to redirect_path(citizen), notice: t("cidadaobr.household_members.flash.linked")
    rescue ActiveRecord::RecordInvalid => e
      redirect_to redirect_path(citizen), alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      member = HouseholdMember.joins(:household).merge(scoped_households).find(params[:id])
      household = member.household
      citizen = member.citizen
      CommandBus.dispatch(Territory::Commands::UnlinkHouseholdMember, household_member: member)
      redirect_to params[:citizen_id].present? ? web_citizen_path(citizen) : web_household_path(household),
                  notice: t("cidadaobr.household_members.flash.removed")
    end

    private

    def set_household
      household_id = params[:household_id] || household_member_params[:household_id]
      @household = scoped_households.find(household_id)
    end

    def set_citizen_from_params
      return unless params[:citizen_id].present?

      @citizen = scoped_citizens.find(params[:citizen_id])
    end

    def household_member_params
      params.expect(household_member: %i[citizen_id household_id family_reference])
    end

    def redirect_path(citizen)
      params[:citizen_id].present? ? web_citizen_path(citizen) : web_household_path(@household)
    end
  end
end
