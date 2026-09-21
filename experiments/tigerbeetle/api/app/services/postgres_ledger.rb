class PostgresLedger
  def provision_utility(utility_id)
    create_accounts([
      account(LedgerIds.funding_account, Ledger::MONEY, Ledger::FUNDING),
      account(LedgerIds.account(utility_id, :energy), Ledger::ENERGY, Ledger::UTILITY_SUPPLY),
      account(LedgerIds.account(utility_id, :revenue), Ledger::MONEY, Ledger::UTILITY_REVENUE)
    ])
  end

  def provision_meter(meter_id)
    create_accounts([
      account(LedgerIds.account(meter_id, :energy), Ledger::ENERGY, Ledger::METER_CONSUMPTION),
      account(LedgerIds.account(meter_id, :prepaid), Ledger::MONEY, Ledger::METER_PREPAID, true)
    ])
  end

  def top_up(id:, meter_id:, amount:)
    transfer = {
      id: LedgerIds.transfer(id, :top_up), event_id: id,
      debit_account_id: LedgerIds.funding_account,
      credit_account_id: LedgerIds.account(meter_id, :prepaid),
      amount:, ledger: Ledger::MONEY, code: Ledger::TOP_UP
    }
    record([ transfer ])
  end

  def record_readings(readings)
    readings.map do |reading|
      charge = reading.fetch(:consumption_wh) * reading.fetch(:tariff)
      transfers = [
        {
          id: LedgerIds.transfer(reading.fetch(:id), :energy), event_id: reading.fetch(:id),
          debit_account_id: LedgerIds.account(reading.fetch(:utility_id), :energy),
          credit_account_id: LedgerIds.account(reading.fetch(:meter_id), :energy),
          amount: reading.fetch(:consumption_wh), ledger: Ledger::ENERGY, code: Ledger::ENERGY_READING
        },
        {
          id: LedgerIds.transfer(reading.fetch(:id), :charge), event_id: reading.fetch(:id),
          debit_account_id: LedgerIds.account(reading.fetch(:meter_id), :prepaid),
          credit_account_id: LedgerIds.account(reading.fetch(:utility_id), :revenue),
          amount: charge, ledger: Ledger::MONEY, code: Ledger::READING_CHARGE
        }
      ]
      record(transfers).merge(id: reading.fetch(:id), consumption_wh: reading.fetch(:consumption_wh), charge_micros: charge)
    rescue Ledger::InsufficientFunds
      { id: reading.fetch(:id), status: "insufficient_funds", consumption_wh: reading.fetch(:consumption_wh), charge_micros: charge }
    end
  end

  def balance(meter_id)
    energy, prepaid = LedgerAccount.where(id: [
      LedgerIds.account(meter_id, :energy), LedgerIds.account(meter_id, :prepaid)
    ]).index_by(&:id).values_at(
      LedgerIds.account(meter_id, :energy), LedgerIds.account(meter_id, :prepaid)
    )
    raise Ledger::NotFound unless energy && prepaid

    {
      consumption_wh: energy.credits_posted.to_i - energy.debits_posted.to_i,
      prepaid_balance_micros: prepaid.credits_posted.to_i - prepaid.debits_posted.to_i
    }
  end

  def find_event(id)
    transfers = LedgerTransfer.where(event_id: id).order(:code)
    raise Ledger::NotFound if transfers.empty?

    serialize_event(transfers)
  end

  private

  def create_accounts(accounts)
    LedgerAccount.insert_all(accounts, unique_by: :id)
  end

  def account(id, ledger, code, limit = false)
    { id:, ledger:, code:, debits_must_not_exceed_credits: limit, created_at: Time.current, updated_at: Time.current }
  end

  def record(transfers)
    status = nil
    LedgerAccount.transaction do
      existing = LedgerTransfer.where(event_id: transfers.first.fetch(:event_id)).order(:code).to_a
      unless existing.empty?
        raise Ledger::Conflict unless same_transfers?(existing, transfers)

        status = "exists"
        next
      end

      account_ids = transfers.flat_map { |transfer| [ transfer.fetch(:debit_account_id), transfer.fetch(:credit_account_id) ] }.uniq.sort
      accounts = LedgerAccount.lock.where(id: account_ids).order(:id).index_by(&:id)
      raise Ledger::NotFound unless accounts.size == account_ids.size

      transfers.each do |transfer|
        debit = accounts.fetch(transfer.fetch(:debit_account_id))
        credit = accounts.fetch(transfer.fetch(:credit_account_id))
        amount = transfer.fetch(:amount)
        if debit.debits_must_not_exceed_credits && debit.debits_posted + amount > debit.credits_posted
          raise Ledger::InsufficientFunds
        end

        debit.debits_posted += amount
        credit.credits_posted += amount
        LedgerTransfer.create!(transfer)
      end
      accounts.each_value(&:save!)
      status = "created"
    end
    { status: }
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def same_transfers?(existing, expected)
    existing.map { |transfer| comparable(transfer.attributes.symbolize_keys) } == expected.sort_by { |transfer| transfer.fetch(:code) }.map { |transfer| comparable(transfer) }
  end

  def comparable(transfer)
    transfer.slice(:id, :event_id, :debit_account_id, :credit_account_id, :ledger, :code).merge(amount: transfer.fetch(:amount).to_i)
  end

  def serialize_event(transfers)
    energy = transfers.find { |transfer| transfer.code == Ledger::ENERGY_READING }
    charge = transfers.find { |transfer| transfer.code == Ledger::READING_CHARGE }
    top_up = transfers.find { |transfer| transfer.code == Ledger::TOP_UP }
    return { id: transfers.first.event_id, type: "top_up", amount_micros: top_up.amount.to_i } if top_up

    { id: transfers.first.event_id, type: "meter_reading", consumption_wh: energy.amount.to_i, charge_micros: charge.amount.to_i }
  end
end
