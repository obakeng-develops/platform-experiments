require "digest"

module LedgerIds
  module_function

  def account(owner_id, role)
    uuid("account:#{owner_id}:#{role}")
  end

  def transfer(event_id, role)
    uuid("transfer:#{event_id}:#{role}")
  end

  def funding_account
    uuid("account:global:funding")
  end

  def integer(uuid_value)
    uuid_value.delete("-").to_i(16)
  end

  def uuid(value)
    hex = Digest::SHA256.hexdigest(value)[0, 32]
    [ hex[0, 8], hex[8, 4], hex[12, 4], hex[16, 4], hex[20, 12] ].join("-")
  end
end
