class LedgerAccount < ApplicationRecord
  validates :ledger, :code, presence: true
end
