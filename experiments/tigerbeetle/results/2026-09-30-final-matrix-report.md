# Final Locust Matrix Report

**Run window:** 2026-09-29 to 2026-09-30 UTC. **Status:** Complete. This is a local API-level comparison, not a production capacity test.

## Run setup

- Backends: PostgreSQL and TigerBeetle
- Utility counts: 1, 10 and 1,000
- Batch sizes: 1, 10, 100 and 1,000 readings per request
- Repetitions: 3 for each of 24 combinations, 72 Locust reports total
- Locust: 32 users, spawn rate 16 users per second, 60 seconds per case
- Meters: 1,000 per case
- A reset and seed ran before each case

Both backend test suites passed before the matrix. Each reported 7 tests and 42 assertions with no failures.

All 72 Locust reports recorded requests. Every request succeeded. The reports contain 963,734 HTTP requests: 128,650 for PostgreSQL and 835,084 for TigerBeetle. Those requests represent 588,154 PostgreSQL readings and 19,928,215 TigerBeetle readings across all configurations. The totals include different batch sizes and are not a direct comparison.

## Median throughput and request latency

Each throughput value is the median of the three runs' `Requests/s × batch size`. Each p95 value is the median of the three run-level p95 values. Latency is for the full HTTP request, including every reading in the batch.

| Utilities | Batch | PostgreSQL readings/s | PostgreSQL p95 | TigerBeetle readings/s | TigerBeetle p95 |
|---:|---:|---:|---:|---:|---:|
| 1 | 1 | 211.7 | 180 ms | 953.6 | 46 ms |
| 1 | 10 | 358.9 | 890 ms | 5,763.0 | 81 ms |
| 1 | 100 | 366.1 | 7,600 ms | 13,808.7 | 320 ms |
| 1 | 1,000 | 365.0 | 36,000 ms | 19,497.1 | 2,200 ms |
| 10 | 1 | 192.9 | 210 ms | 1,034.9 | 42 ms |
| 10 | 10 | 307.4 | 1,100 ms | 5,604.8 | 92 ms |
| 10 | 100 | 310.9 | 10,000 ms | 13,753.2 | 320 ms |
| 10 | 1,000 | 323.4 | 42,000 ms | 19,969.6 | 2,100 ms |
| 1,000 | 1 | 203.4 | 160 ms | 867.0 | 46 ms |
| 1,000 | 10 | 316.4 | 920 ms | 5,004.7 | 87 ms |
| 1,000 | 100 | 337.7 | 8,000 ms | 11,794.8 | 340 ms |
| 1,000 | 1,000 | 316.8 | 41,000 ms | 18,274.2 | 2,200 ms |

TigerBeetle's median readings-per-second was higher in all 12 cells, by 4.3× to 61.7×. In the one-utility case, which directs every meter to the same utility accounts, the measured difference ranged from 4.5× at batch size 1 to 53.4× at batch size 1,000.

The result applies to these implementations and this host. Each request passes through Locust, HTTP, Rails and the selected ledger. It does not isolate the database engine from application overhead.

## Run integrity and limits

- Each of the 24 combinations has 3 Locust reports. There were no zero-request runs and no request failures.
- No Komodo, ClickStack or Lago containers appeared in any of the 72 environment snapshots. The BuildKit container was present.
- Two runs have no final container-stat snapshot because the long-running shell received SIGTERM after Locust wrote its report. Their Locust CSVs and environment snapshots are present: `20260929T154516Z-postgres-u32-b100-utilities1000` and `20260929T192457Z-tigerbeetle-u32-b1-utilities1000`.
- The matrix ran in a fixed order, with PostgreSQL cases before TigerBeetle cases in each pass.
- The host was a 16 GB MacBook Pro with an M1 Pro, running macOS 26.6.1. Docker client 29.8.1, server 29.2.1 and Compose 5.1.0 ran PostgreSQL 17.6, TigerBeetle 0.17.9 and Locust 2.46.6.
- The run recorded container CPU and memory snapshots. It did not collect PostgreSQL lock-wait durations or post-run database size.
- Query plans were not collected during timed runs.

The matrix supports a comparison of the end-to-end API paths on this machine. It does not establish production capacity or show that append-only storage alone caused the difference. The PostgreSQL lock-wait and database-size measurements remain follow-up work.

## Raw reports

The tracked [per-run dataset](2026-09-30-final-matrix-runs.csv) contains one row for each of the 72 final runs, including request counts, failure counts, throughput and latency percentiles. Full Locust HTML reports, time-series files and environment snapshots remain local and are excluded from the PR. Earlier timestamped files belong to interrupted or contaminated attempts. Use the per-run dataset for this comparison.
