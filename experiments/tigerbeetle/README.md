# TigerBeetle

**Status:** Ready for measurement

This experiment asks one question: what happens when we model a high-contention financial workload as mutable relational state versus an append-only ledger?

One Rails API implements the same prepaid electricity-meter workflow with PostgreSQL and TigerBeetle. Locust sends the same HTTP workload to each implementation.

## Defining The Workload

Each utility owns an energy supply account and a revenue account. Each meter owns an energy consumption account and a prepaid money account.

A meter reading creates two transfers:

1. Energy moves from the utility supply account to the meter consumption account.
2. Money moves from the meter prepaid account to the utility revenue account.

Both transfers succeed or fail together. The prepaid account cannot spend more than it has received. Amounts use integer units: Wh for energy and micros for money.

TigerBeetle records the pair as linked transfers. PostgreSQL locks the affected account rows, inserts immutable transfer rows and updates mutable account balances in one database transaction.

## Stating The Hypotheses

- PostgreSQL transactions will wait on row locks when many meters update the same utility accounts.
- TigerBeetle will avoid per-row lock management. Its single-threaded state machine will process batched transfers serially.
- Larger batches will improve TigerBeetle throughput because one request amortizes replication and I/O costs across more transfers.
- Rails and HTTP overhead may hide database differences at low concurrency and batch size one.

These are hypotheses. Add claims to [Results](#recording-results) only after collecting measurements.

## Understanding The Implementations

The API lives in [`api/`](api/). Set `LEDGER_BACKEND` to `postgres` or `tigerbeetle` to choose the ledger.

PostgreSQL stores metadata in both modes. The reading path caches immutable meter-to-utility metadata in the Rails process. The TigerBeetle path does not write transaction data to PostgreSQL.

TigerBeetle performance comes from its narrow interface rather than append-only storage alone. It uses fixed-size account and transfer records, database-enforced accounting rules, automatic client batching and a serial state machine without row locks. The PostgreSQL implementation must coordinate several general-purpose tables and mutable rows for each reading.

The hot-account case appears in PostgreSQL when concurrent transactions update the same utility supply and revenue rows. PostgreSQL grants one transaction the conflicting row lock while the others wait. TigerBeetle serializes all events by design, then uses batching to execute that serial work with less coordination overhead.

## API

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/utilities` | Provision utility ledger accounts |
| `POST` | `/meters` | Provision meter ledger accounts |
| `POST` | `/top_ups` | Add prepaid credit |
| `GET` | `/top_ups/:id` | Look up a top-up |
| `POST` | `/meter_readings` | Submit 1 to 1,000 readings |
| `GET` | `/meter_readings/:id` | Look up a reading |
| `GET` | `/meters/:id` | Read consumption and prepaid balances |

Every write uses a client-generated UUID. Retrying the same UUID and payload has one financial effect. Reusing a UUID with different data returns `409 Conflict`.

There are no update or delete endpoints for financial events. Authentication, rate limiting and event-history pagination are outside this local experiment.

## Recording The Environment

The repository pins:

- Ruby 3.3.4
- Rails 8.1.3.1
- PostgreSQL 17.6
- TigerBeetle server and Ruby client 0.17.9
- Locust 2.46.6

All services run through Docker Compose on macOS. TigerBeetle supports macOS for development, but supports only Linux 5.6 or newer for production. Docker and the Linux VM affect these measurements. Do not treat the results as production capacity numbers.

Before publishing results, record:

```sh
sw_vers
uname -a
docker version
docker compose version
docker stats --no-stream
```

Also record the Mac model, CPU, memory and the CPU and memory assigned to the container VM.

## Running The Checks

Reset and start the complete environment:

```sh
./bin/reset
```

Run the PostgreSQL contract tests on the host:

```sh
cd api
DATABASE_URL=postgres://postgres:postgres@localhost:5432/electricity_meter_api_test \
  LEDGER_BACKEND=postgres bundle exec rails test
```

Run the TigerBeetle contract tests inside Compose because the native client requires Linux `io_uring`:

```sh
docker compose run --rm \
  -e RAILS_ENV=test \
  -e SECRET_KEY_BASE=test \
  -e DATABASE_URL=postgres://postgres:postgres@postgres:5432/electricity_tigerbeetle_test \
  api-tigerbeetle bin/rails db:prepare

docker compose run --rm \
  -e RAILS_ENV=test \
  -e SECRET_KEY_BASE=test \
  -e DATABASE_URL=postgres://postgres:postgres@postgres:5432/electricity_tigerbeetle_test \
  api-tigerbeetle bin/rails test
```

## Running A Benchmark

Run one backend after `./bin/reset`:

```sh
UTILITY_COUNT=1 METER_COUNT=1000 BATCH_SIZE=10 \
USERS=32 RUN_TIME=60s ./bin/benchmark postgres

UTILITY_COUNT=1 METER_COUNT=1000 BATCH_SIZE=10 \
USERS=32 RUN_TIME=60s ./bin/benchmark tigerbeetle
```

Raw Locust CSV and HTML reports are written to `results/`. Multiply request throughput by `BATCH_SIZE` to get accepted meter readings per second. Each accepted reading creates two transfers.

Run the default matrix with:

```sh
./bin/benchmark-matrix
```

The matrix resets storage before each case and tests both backends with utility counts `1`, `10` and `1000`, and batch sizes `1`, `10`, `100` and `1000`. Override `BACKENDS`, `UTILITY_COUNTS` or `BATCH_SIZES` with space-separated values to run a smaller matrix.

One utility produces maximum contention. Increasing the utility count distributes writes across more utility account pairs.

For each case, record:

- Readings and transfers per second
- HTTP p50, p95 and p99 latency
- Request failures
- PostgreSQL lock waits
- Rails, database and Locust CPU and memory
- Database size after the run

Repeat each case at least three times. Report the median and retain every raw result.

## Injecting Failures

During an active workload, stop and restart the selected database:

```sh
docker compose stop postgres
docker compose start postgres
```

```sh
docker compose stop tigerbeetle
docker compose start tigerbeetle
```

Replay the same event UUIDs after recovery and verify that balances change once. Record the injected failure, expected behavior, observed behavior and recovery steps.

This single-replica setup tests restart and retry behavior. It does not test TigerBeetle quorum failover.

## Recording Results

No benchmark result has been recorded yet.

For each run, add the raw result files under `results/` when publishing them and summarize the host configuration, workload parameters and median measurements here.

## Drawing Conclusions

No conclusion has been drawn yet. The implementation and recorded measurements will determine whether the hypotheses hold on this environment.
