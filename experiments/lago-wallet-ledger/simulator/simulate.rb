# frozen_string_literal: true

# Where the Money Lives: models Lago's wallet credit flow twice, once as mutable
# relational state (ported from getlago/lago-api) and once as a TigerBeetle
# ledger, then prints both side by side.
#
#   ./bin/reset && ./bin/simulate [scenario]

require "bigdecimal"
require "tigerbeetle"

LEDGER = 1
CREDIT_SCALE = 100_000 # 1 Lago credit (decimal(30,5)) => 100_000 ledger units

# account codes (TigerBeetle rejects code 0)
ORG_SOURCE, SYSTEM, WALLET = 1, 2, 3
# transfer codes
GRANT, PURCHASE, USAGE = 10, 11, 12

Currency = Struct.new(:subunit_to_unit, :exponent, keyword_init: true)
CURRENCIES = { "USD" => Currency.new(subunit_to_unit: 100, exponent: 2) }.freeze

# --- Lago ------------------------------------------------------------------

# Port of app/models/wallet_credit.rb. The invoiceable round-trip is the part
# that matters: invoiceable credits are pushed through cents and back, so a
# credit that would bill as less than a cent is rejected at creation.
def wallet_credit(wallet, credit_amount, invoiceable: true)
  currency = CURRENCIES.fetch(wallet.currency)
  amount = (BigDecimal(credit_amount.to_s) * wallet.rate_amount).round(currency.exponent)
  amount_cents = (amount * currency.subunit_to_unit).to_i

  {
    amount:,
    amount_cents:,
    credit_amount: invoiceable ? amount.fdiv(wallet.rate_amount) : credit_amount
  }
end

class LagoWallet
  attr_reader :transactions, :consumptions
  attr_accessor :balance_cents, :credits_balance, :consumed_amount_cents,
    :consumed_credits, :ongoing_usage_balance_cents, :ongoing_balance_cents,
    :depleted_ongoing_balance, :traceable

  def initialize(rate_amount:, currency: "USD", traceable: true)
    @rate_amount = rate_amount
    @currency = currency
    @traceable = traceable
    @balance_cents = 0
    @credits_balance = BigDecimal(0)
    @consumed_amount_cents = 0
    @consumed_credits = BigDecimal(0)
    @ongoing_usage_balance_cents = 0
    @ongoing_balance_cents = 0
    @depleted_ongoing_balance = false
    @transactions = []
    @consumptions = []
    @clock = 0
  end

  attr_reader :rate_amount, :currency

  def next_created_at
    @clock += 1
  end

  # app/services/wallet_transactions/create_service.rb
  def create_transaction(credits:, transaction_type:, status:, transaction_status:, priority: 50)
    credit = wallet_credit(self, credits, invoiceable: transaction_status != :voided)
    id = "wt-#{transactions.length + 1}"
    row = {
      id:,
      transaction_type:,
      status:,
      transaction_status:,
      priority:,
      amount: credit[:amount],
      amount_cents: credit[:amount_cents],
      credit_amount: credit[:credit_amount],
      created_at: next_created_at,
      remaining_amount_cents: initial_remaining(transaction_type, transaction_status, credit[:amount_cents])
    }
    transactions << row
    row
  end

  # app/services/wallet_transactions/create_service.rb#initial_remaining_amount_cents
  def initial_remaining(transaction_type, transaction_status, amount_cents)
    return nil unless traceable
    return nil unless transaction_type == :inbound
    return nil unless transaction_status == :granted

    amount_cents
  end

  # app/services/wallets/balance/increase_service.rb
  def increase!(row)
    self.balance_cents += row[:amount_cents]
    self.credits_balance += row[:credit_amount]
  end

  # app/services/wallets/balance/decrease_service.rb
  def decrease!(row)
    self.balance_cents -= row[:amount_cents]
    self.credits_balance -= row[:credit_amount]
    self.consumed_amount_cents += row[:amount_cents]
    self.consumed_credits += row[:credit_amount]
  end

  # app/services/wallet_transactions/track_consumption_service.rb
  #
  def consume!(outbound_row, inbounds: nil)
    inbounds ||= available_inbounds
    available = inbounds.sum { |inbound| inbound[:remaining_amount_cents] }
    if outbound_row[:amount_cents] > available
      raise "exceeds_available_amount: #{outbound_row[:amount_cents]} > #{available}"
    end

    amount_left = outbound_row[:amount_cents]
    drawn = inbounds.filter_map do |inbound|
      break nil if amount_left <= 0

      take = [ inbound[:remaining_amount_cents], amount_left ].min
      # In Lago this is a decrement! that skips validations and relies on
      # Postgres to reject a negative result.
      inbound[:remaining_amount_cents] -= take
      amount_left -= take
      { inbound: inbound[:id], outbound: outbound_row[:id], consumed_amount_cents: take }
    end
    consumptions.concat(drawn)
    drawn
  end

  # scope :in_consumption_order - priority asc, granted first, then created_at
  def available_inbounds
    transactions.select { |t| t[:transaction_type] == :inbound && t[:status] == :settled && t[:remaining_amount_cents].to_i.positive? }
      .sort_by { |t| [ t[:priority], t[:transaction_status] == :granted ? 0 : 1, t[:created_at] ] }
  end

  # app/services/wallets/balance/refresh_ongoing_usage_service.rb
  def refresh_ongoing!(usage_amount_cents)
    self.ongoing_usage_balance_cents = usage_amount_cents
    self.ongoing_balance_cents = balance_cents - usage_amount_cents
    unless depleted_ongoing_balance == (ongoing_balance_cents <= 0)
      self.depleted_ongoing_balance = ongoing_balance_cents <= 0
    end
  end
end

# --- TigerBeetle -----------------------------------------------------------

class Ledger
  def initialize
    @client = TigerBeetle::Client.new(
      cluster_id: Integer(ENV.fetch("TB_CLUSTER_ID", 0)),
      replica_addresses: ENV.fetch("TB_ADDRESS", "127.0.0.1:3000")
    )
    @next_id = 0
  end

  def close = @client.close

  def open_account(name, code, flags = TigerBeetle::AccountFlags::NONE)
    id = uid
    status = @client.create_accounts([ TigerBeetle::Account.new(id:, ledger: LEDGER, code:, flags:) ]).first.status
    assert_ok(status, "account #{name}")
    id
  end

  def debit_credit(debit_id, credit_id, amount, code, flags = TigerBeetle::TransferFlags::NONE)
    transfer(id: uid,
      debit_account_id: debit_id, credit_account_id: credit_id, amount:, ledger: LEDGER, code:, flags:)
  end

  # Posting or voiding a pending transfer is itself a new event that references
  # the pending transfer by id. It must repeat the pending transfer's code, and
  # full pending amount.
  def settle(pending, flag)
    @client.create_transfers([ TigerBeetle::Transfer.new(
      id: uid, ledger: LEDGER, code: pending.code, flags: flag,
      pending_id: pending.id, amount: pending.amount
    ) ]).first.tap { |result| assert_ok(result.status, "settle #{pending.id}") }
  end

  def create(transfers)
    return if transfers.empty?

    @client.create_transfers(transfers).each { |result| assert_ok(result.status, "transfer") }
  end

  def balance(account_id)
    account = @client.lookup_accounts([ account_id ]).first
    return nil unless account

    {
      posted: account.credits_posted - account.debits_posted,
      pending: account.credits_pending - account.debits_pending,
      available: (account.credits_posted - account.debits_posted) +
        (account.credits_pending - account.debits_pending)
    }
  end

  private

  def transfer(id:, debit_account_id:, credit_account_id:, amount:, ledger:, code:, flags:)
    TigerBeetle::Transfer.new(id:, debit_account_id:, credit_account_id:, amount:, ledger:, code:, flags:)
  end

  def uid = (@next_id += 1)

  def assert_ok(status, what)
    ok = [ TigerBeetle::CreateAccountStatus::CREATED, TigerBeetle::CreateAccountStatus::EXISTS,
      TigerBeetle::CreateTransferStatus::CREATED, TigerBeetle::CreateTransferStatus::EXISTS ].include?(status)
    raise "TigerBeetle rejected #{what}: #{status}" unless ok
  end
end

# --- Comparison ------------------------------------------------------------

UNITS_PER_CREDIT = CREDIT_SCALE

def credits_to_cents(credits, rate_amount)
  (BigDecimal(credits.to_s) * rate_amount * 100).round.to_i
end

def report(wallet, ledger, wallet_account_id, expectations)
  posted = ledger.balance(wallet_account_id)
  posted_credits = BigDecimal(posted[:posted].to_s) / UNITS_PER_CREDIT
  available_credits = BigDecimal(posted[:available].to_s) / UNITS_PER_CREDIT
  derived_cents = credits_to_cents(posted_credits, wallet.rate_amount)
  available_cents = credits_to_cents(available_credits, wallet.rate_amount)
  lago_available_cents = wallet.balance_cents - wallet.ongoing_usage_balance_cents

  puts
  puts "  #{'metric'.ljust(30)}#{'Lago'.ljust(20)}#{'TigerBeetle'.ljust(20)}match"
  puts "  #{'-' * 30}#{'-' * 20}#{'-' * 20}-----"
  row("balance (cents)", wallet.balance_cents, derived_cents, wallet.balance_cents == derived_cents)
  row("balance (credits)", wallet.credits_balance, posted_credits,
    (wallet.credits_balance.to_f - posted_credits.to_f).abs < 0.00001)
  row("available balance (cents)", lago_available_cents, available_cents,
    lago_available_cents == available_cents)

  puts
  puts "  transactions"
  wallet.transactions.each do |t|
    remaining = t[:remaining_amount_cents] ? "#{t[:remaining_amount_cents]}c left" : "n/a"
    puts "    #{t[:id].ljust(8)} #{t[:transaction_type].to_s.ljust(8)} #{t[:transaction_status].to_s.ljust(10)} " \
      "#{format('%d', t[:amount_cents]).rjust(8)}c  #{remaining}"
  end
  unless wallet.consumptions.empty?
    puts "  consumptions"
    wallet.consumptions.each do |c|
      puts "    #{c[:inbound]} -> #{c[:outbound]}  #{format('%d', c[:consumed_amount_cents])}c"
    end
  end

  expectations.each { |label, ok| puts "\n  #{ok ? 'ok  ' : 'FAIL'} #{label}" }
  $failures += expectations.count { |_, ok| !ok }
end

def row(label, lago, tb, match)
  puts "  #{label.ljust(30)}#{lago.to_s.ljust(20)}#{tb.to_s.ljust(20)}#{match ? 'ok' : 'MISMATCH'}"
  $failures += 1 unless match
end

# --- Scenarios -------------------------------------------------------------

$failures = 0

def scenario_grant(ledger)
  puts "\n== grant =="
  org = ledger.open_account("org-source", ORG_SOURCE)
  account = ledger.open_account("grant-wallet", WALLET, TigerBeetle::AccountFlags::DEBITS_MUST_NOT_EXCEED_CREDITS)
  wallet = LagoWallet.new(rate_amount: 1.0)

  row_wt = wallet.create_transaction(credits: 100, transaction_type: :inbound, status: :settled, transaction_status: :granted)
  wallet.increase!(row_wt)
  ledger.create([ ledger.debit_credit(org, account, 100 * UNITS_PER_CREDIT, GRANT) ])

  report(wallet, ledger, account, [
    ["grant adds to balance once", wallet.balance_cents == 10_000],
    ["traceable grant tracks remaining", row_wt[:remaining_amount_cents] == 10_000]  ])
end

def scenario_top_up(ledger)
  puts "\n== top_up pending then settled =="
  org = ledger.open_account("org-source", ORG_SOURCE)
  account = ledger.open_account("topup-wallet", WALLET, TigerBeetle::AccountFlags::DEBITS_MUST_NOT_EXCEED_CREDITS)
  wallet = LagoWallet.new(rate_amount: 1.0)

  purchase = wallet.create_transaction(credits: 50, transaction_type: :inbound, status: :pending, transaction_status: :purchased)
  pending = ledger.debit_credit(org, account, 50 * UNITS_PER_CREDIT, PURCHASE, TigerBeetle::TransferFlags::PENDING)
  ledger.create([ pending ])
  mid = ledger.balance(account)
  lago_available_before_settlement = wallet.balance_cents - wallet.ongoing_usage_balance_cents
  tb_available_before_settlement = credits_to_cents(
    BigDecimal(mid[:available].to_s) / UNITS_PER_CREDIT,
    wallet.rate_amount
  )

  puts "  before provider settlement:"
  puts "    Lago available:      #{lago_available_before_settlement}c"
  puts "    TigerBeetle pending: #{tb_available_before_settlement}c available"

  purchase[:status] = :settled
  wallet.increase!(purchase)
  ledger.settle(pending, TigerBeetle::TransferFlags::POST_PENDING_TRANSFER)

  report(wallet, ledger, account, [
    ["pending purchase creates no Lago balance", lago_available_before_settlement.zero?],
    ["pending TB credit counts toward available", tb_available_before_settlement == 5_000],
    ["balance agrees after settlement", wallet.balance_cents == 5_000]  ])
  puts "\n  For real payment flows, create the posted TB credit only after provider settlement."
end

def scenario_spend(ledger)
  puts "\n== spend: usage accrual as pending debit, posted at invoice =="
  org = ledger.open_account("org-source", ORG_SOURCE)
  account = ledger.open_account("spend-wallet", WALLET, TigerBeetle::AccountFlags::DEBITS_MUST_NOT_EXCEED_CREDITS)
  system = ledger.open_account("system", SYSTEM)
  wallet = LagoWallet.new(rate_amount: 1.0)

  grant = wallet.create_transaction(credits: 100, transaction_type: :inbound, status: :settled, transaction_status: :granted)
  wallet.increase!(grant)
  ledger.create([ ledger.debit_credit(org, account, 100 * UNITS_PER_CREDIT, GRANT) ])

  pending = ledger.debit_credit(account, system, 30 * UNITS_PER_CREDIT, USAGE, TigerBeetle::TransferFlags::PENDING)
  ledger.create([ pending ])
  wallet.refresh_ongoing!(3_000)

  invoiced = wallet.create_transaction(credits: 30, transaction_type: :outbound, status: :settled, transaction_status: :invoiced)
  wallet.decrease!(invoiced)
  wallet.consume!(invoiced, inbounds: [ grant ])
  ledger.settle(pending, TigerBeetle::TransferFlags::POST_PENDING_TRANSFER)
  wallet.refresh_ongoing!(0)

  report(wallet, ledger, account, [
    ["balance after invoice", wallet.balance_cents == 7_000],
    ["7,000 cents remain in the granted lot", grant[:remaining_amount_cents] == 7_000],
    ["one consumption row", wallet.consumptions.size == 1]  ])
end

def scenario_void(ledger)
  puts "\n== void =="
  org = ledger.open_account("org-source", ORG_SOURCE)
  account = ledger.open_account("void-wallet", WALLET, TigerBeetle::AccountFlags::DEBITS_MUST_NOT_EXCEED_CREDITS)
  system = ledger.open_account("system", SYSTEM)
  wallet = LagoWallet.new(rate_amount: 1.0)

  grant = wallet.create_transaction(credits: 100, transaction_type: :inbound, status: :settled, transaction_status: :granted)
  wallet.increase!(grant)
  ledger.create([ ledger.debit_credit(org, account, 100 * UNITS_PER_CREDIT, GRANT) ])

  pending = ledger.debit_credit(account, system, 40 * UNITS_PER_CREDIT, USAGE, TigerBeetle::TransferFlags::PENDING)
  ledger.create([ pending ])
  wallet.refresh_ongoing!(4_000)

  # This is still unbilled usage in Lago, so cancelling it clears the derived
  # usage balance. No outbound transaction or lot consumption has happened yet.
  wallet.refresh_ongoing!(0)

  # TigerBeetle void: the pending transfer never existed as a fact.
  ledger.settle(pending, TigerBeetle::TransferFlags::VOID_PENDING_TRANSFER)

  report(wallet, ledger, account, [
    ["Lago returns to the full balance", wallet.balance_cents == 10_000],
    ["the grant pool remains untouched", grant[:remaining_amount_cents] == 10_000]  ])
  puts "\n  Both balances return to 100 credits. Lago clears derived ongoing usage;"
  puts "  TigerBeetle voids the pending debit. This is an analogy, not a claim that"
  puts "  Lago creates an equivalent voided wallet transaction for unbilled usage."
end

def scenario_multi_lot(ledger)
  puts "\n== multi_lot: one spend from three inbound lots =="
  org = ledger.open_account("org-source", ORG_SOURCE)
  account = ledger.open_account("multilot-wallet", WALLET, TigerBeetle::AccountFlags::DEBITS_MUST_NOT_EXCEED_CREDITS)
  system = ledger.open_account("system", SYSTEM)
  wallet = LagoWallet.new(rate_amount: 0.3)

  lots = [
    wallet.create_transaction(credits: 10, transaction_type: :inbound, status: :settled, transaction_status: :purchased),
    wallet.create_transaction(credits: 20, transaction_type: :inbound, status: :settled, transaction_status: :granted, priority: 10),
    wallet.create_transaction(credits: 30, transaction_type: :inbound, status: :settled, transaction_status: :granted, priority: 20)
  ]
  lots.each do |lot|
    wallet.increase!(lot)
    ledger.create([ ledger.debit_credit(org, account, (lot[:credit_amount] * UNITS_PER_CREDIT).round, GRANT) ])
  end

  spend = wallet.create_transaction(credits: 25, transaction_type: :outbound, status: :settled, transaction_status: :invoiced)
  wallet.decrease!(spend)
  drawn = wallet.consume!(spend)
  total = (drawn.sum { |c| c[:consumed_amount_cents] })

  # TigerBeetle: a transfer is one debit and one credit. There is no "draw from
  # three lots". The flat model records only the aggregate.
  ledger.create([ ledger.debit_credit(account, system, (spend[:credit_amount] * UNITS_PER_CREDIT).round, USAGE) ])

  puts "  Lago drew #{drawn.size} consumption rows totalling #{total}c: " \
    "#{drawn.map { |c| "#{c[:inbound]}=#{c[:consumed_amount_cents]}c" }.join(', ')}"
  puts "  TigerBeetle records ONE transfer. Lot provenance is not representable."

  report(wallet, ledger, account, [
    ["Lago preserves two drawable lots", drawn.size == 2],
    ["aggregate credits agree", (wallet.credits_balance.to_f - BigDecimal(ledger.balance(account)[:posted].to_s).to_f / UNITS_PER_CREDIT).abs < 0.00001]  ])
end

def scenario_threshold_refill(ledger)
  puts "\n== threshold_refill: a wallet designed to go negative =="
  org = ledger.open_account("org-source", ORG_SOURCE)
  # Threshold wallets intentionally have no overdraft-prevention flag.
  account = ledger.open_account("threshold-wallet", WALLET)
  system = ledger.open_account("system", SYSTEM)
  # ponytail: disable per-grant attribution here to isolate the threshold flow.
  wallet = LagoWallet.new(rate_amount: 1.0, traceable: false)

  grant = wallet.create_transaction(credits: 10, transaction_type: :inbound, status: :settled, transaction_status: :granted)
  wallet.increase!(grant)
  ledger.create([ ledger.debit_credit(org, account, 10 * UNITS_PER_CREDIT, GRANT) ])

  # Unbilled usage is an allocation, not yet an outbound transaction. Lago lets
  # this ongoing amount exceed the balance so the threshold rule can refill it.
  wallet.refresh_ongoing!(2_500)
  pending = ledger.debit_credit(account, system, 25 * UNITS_PER_CREDIT, USAGE, TigerBeetle::TransferFlags::PENDING)
  ledger.create([ pending ])
  overdraft = wallet.ongoing_balance_cents

  refill = wallet.create_transaction(credits: 30, transaction_type: :inbound, status: :settled, transaction_status: :granted)
  wallet.increase!(refill)
  ledger.create([ ledger.debit_credit(org, account, 30 * UNITS_PER_CREDIT, GRANT) ])
  wallet.refresh_ongoing!(2_500)

  invoice = wallet.create_transaction(credits: 25, transaction_type: :outbound, status: :settled,
    transaction_status: :invoiced)
  wallet.decrease!(invoice)
  ledger.settle(pending, TigerBeetle::TransferFlags::POST_PENDING_TRANSFER)
  wallet.refresh_ongoing!(0)

  report(wallet, ledger, account, [
    ["ongoing allocation goes negative before invoice", overdraft == -1_500],
    ["refill restores the balance", wallet.balance_cents == 1_500]  ])
  puts "\n  The ledger can represent negative availability without an explicit balance field."
  puts "  Lago still owns the threshold rule that decides when and how much to refill."
end

SCENARIOS = {
  "grant" => :scenario_grant,
  "top_up" => :scenario_top_up,
  "spend" => :scenario_spend,
  "void" => :scenario_void,
  "multi_lot" => :scenario_multi_lot,
  "threshold_refill" => :scenario_threshold_refill
}.freeze

def selfcheck(ledger)
  org = ledger.open_account("org-source", ORG_SOURCE)
  account = ledger.open_account("selfcheck-wallet", WALLET)
  ledger.create([ ledger.debit_credit(org, account, 25 * UNITS_PER_CREDIT, GRANT) ])
  raise "expected 25 credits" unless ledger.balance(account)[:posted] == 25 * UNITS_PER_CREDIT
  raise "expected wallet id" unless account.positive?
end

selected = ARGV.empty? ? SCENARIOS.keys : ARGV
selected.each { |name| raise "unknown scenario: #{name}" unless SCENARIOS.key?(name) }

ledger = Ledger.new
selfcheck(ledger)
SCENARIOS.each { |name, run| send(run, ledger) if selected.include?(name) }
ledger.close

puts "\n#{$failures.zero? ? 'all checks passed' : "#{$failures} mismatches"}"
exit($failures.zero? ? 0 : 1)
