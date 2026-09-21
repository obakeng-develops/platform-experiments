require "tigerbeetle"

class TigerBeetleLedger
  SUCCESSFUL_ACCOUNT_STATUSES = [
    TigerBeetle::CreateAccountStatus::CREATED,
    TigerBeetle::CreateAccountStatus::EXISTS
  ].freeze
  SUCCESSFUL_TRANSFER_STATUSES = [
    TigerBeetle::CreateTransferStatus::CREATED,
    TigerBeetle::CreateTransferStatus::EXISTS
  ].freeze

  def initialize
    @client = TigerBeetle::Client.new(
      cluster_id: Integer(ENV.fetch("TB_CLUSTER_ID", 0)),
      replica_addresses: ENV.fetch("TB_ADDRESS", "127.0.0.1:3000")
    )
  end

  def close
    @client.close unless @client.closed?
  end

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
      account(
        LedgerIds.account(meter_id, :prepaid), Ledger::MONEY, Ledger::METER_PREPAID,
        TigerBeetle::AccountFlags::DEBITS_MUST_NOT_EXCEED_CREDITS
      )
    ])
  end

  def top_up(id:, meter_id:, amount:)
    transfer = transfer(
      LedgerIds.transfer(id, :top_up), id,
      LedgerIds.funding_account, LedgerIds.account(meter_id, :prepaid),
      amount, Ledger::MONEY, Ledger::TOP_UP
    )
    result = @client.create_transfers([ transfer ]).first
    transfer_result(result.status)
  end

  def record_readings(readings)
    transfers = readings.flat_map do |reading|
      charge = reading.fetch(:consumption_wh) * reading.fetch(:tariff)
      [
        transfer(
          LedgerIds.transfer(reading.fetch(:id), :energy), reading.fetch(:id),
          LedgerIds.account(reading.fetch(:utility_id), :energy), LedgerIds.account(reading.fetch(:meter_id), :energy),
          reading.fetch(:consumption_wh), Ledger::ENERGY, Ledger::ENERGY_READING, TigerBeetle::TransferFlags::LINKED
        ),
        transfer(
          LedgerIds.transfer(reading.fetch(:id), :charge), reading.fetch(:id),
          LedgerIds.account(reading.fetch(:meter_id), :prepaid), LedgerIds.account(reading.fetch(:utility_id), :revenue),
          charge, Ledger::MONEY, Ledger::READING_CHARGE
        )
      ]
    end

    results = @client.create_transfers(transfers)
    readings.each_with_index.map do |reading, index|
      charge = reading.fetch(:consumption_wh) * reading.fetch(:tariff)
      pair = transfers.slice(index * 2, 2)
      statuses = results.slice(index * 2, 2).map(&:status)
      status = reading_status(statuses, pair)
      { id: reading.fetch(:id), status:, consumption_wh: reading.fetch(:consumption_wh), charge_micros: charge }
    end
  end

  def balance(meter_id)
    ids = [ LedgerIds.account(meter_id, :energy), LedgerIds.account(meter_id, :prepaid) ]
    accounts = @client.lookup_accounts(ids.map { |id| LedgerIds.integer(id) }).index_by(&:id)
    energy, prepaid = ids.map { |id| accounts[LedgerIds.integer(id)] }
    raise Ledger::NotFound unless energy && prepaid

    {
      consumption_wh: energy.credits_posted - energy.debits_posted,
      prepaid_balance_micros: prepaid.credits_posted - prepaid.debits_posted
    }
  end

  def find_event(id)
    transfer_ids = %i[energy charge top_up].map { |role| LedgerIds.integer(LedgerIds.transfer(id, role)) }
    transfers = @client.lookup_transfers(transfer_ids)
    raise Ledger::NotFound if transfers.empty?

    top_up = transfers.find { |item| item.code == Ledger::TOP_UP }
    return { id:, type: "top_up", amount_micros: top_up.amount } if top_up

    energy = transfers.find { |item| item.code == Ledger::ENERGY_READING }
    charge = transfers.find { |item| item.code == Ledger::READING_CHARGE }
    { id:, type: "meter_reading", consumption_wh: energy.amount, charge_micros: charge.amount }
  end

  private

  def create_accounts(accounts)
    statuses = @client.create_accounts(accounts).map(&:status)
    raise Ledger::Conflict unless statuses.all? { |status| SUCCESSFUL_ACCOUNT_STATUSES.include?(status) }
  end

  def account(id, ledger, code, flags = TigerBeetle::AccountFlags::NONE)
    TigerBeetle::Account.new(id: LedgerIds.integer(id), ledger:, code:, flags:)
  end

  def transfer(id, event_id, debit_id, credit_id, amount, ledger, code, flags = TigerBeetle::TransferFlags::NONE)
    TigerBeetle::Transfer.new(
      id: LedgerIds.integer(id), user_data_128: LedgerIds.integer(event_id),
      debit_account_id: LedgerIds.integer(debit_id), credit_account_id: LedgerIds.integer(credit_id),
      amount:, ledger:, code:, flags:
    )
  end

  def transfer_result(status)
    return { status: "created" } if status == TigerBeetle::CreateTransferStatus::CREATED
    return { status: "exists" } if status == TigerBeetle::CreateTransferStatus::EXISTS
    raise Ledger::InsufficientFunds if status == TigerBeetle::CreateTransferStatus::EXCEEDS_CREDITS
    raise Ledger::NotFound if [ TigerBeetle::CreateTransferStatus::DEBIT_ACCOUNT_NOT_FOUND, TigerBeetle::CreateTransferStatus::CREDIT_ACCOUNT_NOT_FOUND ].include?(status)

    raise Ledger::Conflict, "TigerBeetle transfer status #{status}"
  end

  def reading_status(statuses, transfers)
    return "created" if statuses.all? { |status| status == TigerBeetle::CreateTransferStatus::CREATED }
    return "exists" if statuses.all? { |status| status == TigerBeetle::CreateTransferStatus::EXISTS }
    return "exists" if statuses == [ TigerBeetle::CreateTransferStatus::EXISTS, TigerBeetle::CreateTransferStatus::LINKED_EVENT_FAILED ] && existing_transfers_match?(transfers)
    return "insufficient_funds" if statuses.include?(TigerBeetle::CreateTransferStatus::EXCEEDS_CREDITS)
    raise Ledger::NotFound if statuses.any? { |status| [ TigerBeetle::CreateTransferStatus::DEBIT_ACCOUNT_NOT_FOUND, TigerBeetle::CreateTransferStatus::CREDIT_ACCOUNT_NOT_FOUND ].include?(status) }

    raise Ledger::Conflict, "TigerBeetle transfer statuses #{statuses.join(',')}"
  end

  def existing_transfers_match?(expected)
    existing = @client.lookup_transfers(expected.map(&:id)).index_by(&:id)
    expected.all? do |transfer|
      actual = existing[transfer.id]
      actual && %i[debit_account_id credit_account_id amount user_data_128 ledger code flags].all? do |field|
        actual.public_send(field) == transfer.public_send(field)
      end
    end
  end
end
