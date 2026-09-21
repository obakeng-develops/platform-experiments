class MetersController < ApplicationController
  def create
    attributes = meter_params
    meter = Meter.find_or_initialize_by(id: attributes.fetch(:id))
    if meter.persisted? && meter.slice(:utility_id, :reference) != attributes.slice(:utility_id, :reference).to_h
      raise Ledger::Conflict, "Meter ID was already used with different data"
    end

    created = meter.new_record?
    meter.assign_attributes(attributes)
    meter.save!
    Ledger.current.provision_meter(meter.id)
    render json: meter.slice(:id, :utility_id, :reference), status: created ? :created : :ok
  rescue Ledger::Error
    meter&.destroy if created
    raise
  end

  def show
    meter = Meter.find(params[:id])
    render json: meter.slice(:id, :utility_id, :reference).merge(Ledger.current.balance(meter.id))
  end

  private

  def meter_params
    params.expect(meter: %i[id utility_id reference])
  end
end
