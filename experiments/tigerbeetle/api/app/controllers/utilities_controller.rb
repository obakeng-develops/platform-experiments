class UtilitiesController < ApplicationController
  def create
    attributes = utility_params
    utility = Utility.find_or_initialize_by(id: attributes.fetch(:id))
    if utility.persisted? && utility.slice(:name, :tariff_micros_per_wh) != attributes.slice(:name, :tariff_micros_per_wh).to_h
      raise Ledger::Conflict, "Utility ID was already used with different data"
    end

    created = utility.new_record?
    utility.assign_attributes(attributes)
    utility.save!
    Ledger.current.provision_utility(utility.id)
    render json: utility.slice(:id, :name, :tariff_micros_per_wh), status: created ? :created : :ok
  rescue Ledger::Error
    utility&.destroy if created
    raise
  end

  private

  def utility_params
    params.expect(utility: %i[id name tariff_micros_per_wh])
  end
end
