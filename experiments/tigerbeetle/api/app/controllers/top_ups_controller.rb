class TopUpsController < ApplicationController
  def create
    input = params.expect(top_up: %i[id meter_id amount_micros])
    result = Ledger.current.top_up(
      id: uuid!(input.fetch(:id)),
      meter_id: Meter.ledger_context(uuid!(input.fetch(:meter_id))).fetch(:meter_id),
      amount: positive_integer!(input.fetch(:amount_micros), "amount_micros")
    )
    render json: result.merge(id: input.fetch(:id), meter_id: input.fetch(:meter_id), amount_micros: input.fetch(:amount_micros).to_i), status: :created
  end

  def show
    render json: Ledger.current.find_event(params[:id])
  end
end
