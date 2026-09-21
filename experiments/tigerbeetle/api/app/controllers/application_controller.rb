class ApplicationController < ActionController::API
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  rescue_from ActionController::ParameterMissing do |error|
    render_error("invalid_request", error.message, :unprocessable_entity)
  end
  rescue_from ActiveRecord::RecordInvalid do |error|
    render_error("invalid_request", error.record.errors.full_messages.to_sentence, :unprocessable_entity)
  end
  rescue_from ActiveRecord::RecordNotFound, Ledger::NotFound do
    render_error("not_found", "Resource not found", :not_found)
  end
  rescue_from Ledger::Conflict do |error|
    render_error("idempotency_conflict", error.message.presence || "ID was already used with different data", :conflict)
  end
  rescue_from Ledger::InsufficientFunds do
    render_error("insufficient_funds", "The meter does not have enough prepaid credit", :unprocessable_entity)
  end
  rescue_from ArgumentError do |error|
    render_error("invalid_request", error.message, :unprocessable_entity)
  end

  private

  def render_error(code, message, status)
    render json: { error: { code:, message: } }, status:
  end

  def uuid!(value)
    value = value.to_s
    raise ArgumentError, "invalid UUID" unless UUID_PATTERN.match?(value)

    value
  end

  def positive_integer!(value, name)
    number = Integer(value)
    raise ArgumentError, "#{name} must be greater than zero" unless number.positive?

    number
  end
end
