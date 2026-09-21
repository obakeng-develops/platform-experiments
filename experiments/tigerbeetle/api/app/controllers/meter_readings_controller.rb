class MeterReadingsController < ApplicationController
  MAX_BATCH_SIZE = 1_000

  def create
    inputs = params.require(:readings)
    raise ActionController::ParameterMissing, "readings must contain 1 to #{MAX_BATCH_SIZE} items" unless inputs.is_a?(Array) && inputs.size.between?(1, MAX_BATCH_SIZE)

    readings = inputs.map do |input|
      permitted = input.permit(:id, :meter_id, :consumption_wh)
      context = Meter.ledger_context(uuid!(permitted.fetch(:meter_id)))
      context.merge(
        id: uuid!(permitted.fetch(:id)),
        consumption_wh: positive_integer!(permitted.fetch(:consumption_wh), "consumption_wh")
      )
    end

    render json: { results: Ledger.current.record_readings(readings) }, status: :created
  end

  def show
    render json: Ledger.current.find_event(params[:id])
  end
end
