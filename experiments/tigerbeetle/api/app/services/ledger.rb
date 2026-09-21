module Ledger
  ENERGY = 1
  MONEY = 2

  UTILITY_SUPPLY = 101
  UTILITY_REVENUE = 102
  METER_CONSUMPTION = 201
  METER_PREPAID = 202
  FUNDING = 301

  ENERGY_READING = 1
  READING_CHARGE = 2
  TOP_UP = 3

  class Error < StandardError; end
  class Conflict < Error; end
  class InsufficientFunds < Error; end
  class NotFound < Error; end

  module_function

  def current
    @current ||= PostgresLedger.new
  end

  def reset!
    @current&.close if @current.respond_to?(:close)
    @current = nil
  end
end
