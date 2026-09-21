class LedgerTransfer < ApplicationRecord
  validates :amount, numericality: { only_integer: true, greater_than: 0 }
end
