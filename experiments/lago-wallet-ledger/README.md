# Lago Wallet Ledger

**Status:** Runnable simulation; initial scenarios pass.

This experiment asks: **how can Lago's wallet-credit flows be represented in TigerBeetle, and where does that mapping differ?** It is an isolated model for study, not a Lago integration or production replacement.

The Ruby simulator ports a small part of Lago's wallet behavior and runs the same scenarios against TigerBeetle 0.17.9. It uses no Rails or PostgreSQL. One Lago credit is represented as 100,000 integer ledger units, matching Lago's five-decimal credit precision. Lago's USD amount/cents conversion is shown alongside the credit balance.

## Run it

Docker Compose runs TigerBeetle and the simulator. The native client needs Linux `io_uring`, so the simulator runs in a Linux container with `seccomp=unconfined`, matching the existing TigerBeetle experiment.

```sh
./bin/reset
./bin/simulate
```

`bin/reset` deletes this experiment's Docker volumes, formats a fresh TigerBeetle data file, starts the server, and builds the simulator image. Reset before each run because the simulator uses process-local sequential IDs. To run one scenario, reset first, then pass its name:

```sh
./bin/reset
./bin/simulate multi_lot
```

Scenarios are `grant`, `top_up`, `spend`, `void`, `multi_lot`, and `threshold_refill`. The captured initial output is in [`results/2026-09-30-scenarios.txt`](results/2026-09-30-scenarios.txt).

## What the scenarios show

- **Grant:** one settled Lago inbound transaction maps cleanly to a posted transfer.
- **Top-up:** a pending TigerBeetle credit counts toward the wallet's computed available amount, while Lago does not add a pending purchase to its balance. For the experiment, the credit is posted when the simulated payment settles. This highlights why the real application should wait for provider confirmation before creating a spendable credit.
- **Spend:** Lago's unbilled usage is a derived allocation; a TigerBeetle pending debit is a useful analogue. At invoice time, Lago decreases its aggregate balance and records which grant funded the spend; TigerBeetle posts the pending debit.
- **Void:** the simulator clears Lago's unbilled-usage projection and voids the corresponding pending debit. This is an analogy, not a claim that Lago creates a voided wallet transaction for unbilled usage.
- **Multi-lot:** the aggregate balances agree, but Lago records a spend funded by two granted lots. The single-account TigerBeetle model does not preserve that attribution. Lago also gives purchased transactions no `remaining_amount_cents` pool, so those lots are not drawable in this model.
- **Threshold refill:** Lago allows ongoing usage to exceed a threshold wallet's balance so its refill rule can run. TigerBeetle can represent negative availability when the account has no debit-limit flag; Lago still owns the refill policy.

## Limits

This is a teaching model, not a port of Lago's complete transaction lifecycle. It covers one wallet, USD with two decimal places, a fixed conversion rate, and selected flows from `getlago/lago-api`. It omits payment-provider calls, taxes, fees, locking and asynchronous refresh jobs. The void scenario is deliberately illustrative. The printed comparisons validate only the scenarios and assumptions encoded here.

The corresponding Lago source is in [`getlago/lago-api`](https://github.com/getlago/lago-api), especially `WalletCredit`, `WalletTransaction`, `TrackConsumptionService`, `IncreaseService`, `DecreaseService`, and `RefreshOngoingUsageService`.
