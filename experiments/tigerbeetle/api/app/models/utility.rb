class Utility < ApplicationRecord
  has_many :meters, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :tariff_micros_per_wh, numericality: { only_integer: true, greater_than: 0 }
end
