class Meter < ApplicationRecord
  belongs_to :utility

  validates :reference, presence: true, uniqueness: { scope: :utility_id }

  def self.ledger_context(id)
    Rails.cache.fetch("meter-ledger-context/#{id}") do
      meter = includes(:utility).find(id)
      { meter_id: meter.id, utility_id: meter.utility_id, tariff: meter.utility.tariff_micros_per_wh }
    end
  end
end
