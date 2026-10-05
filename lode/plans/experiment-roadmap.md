# Experiment Roadmap

The experiments are planned in this order:

1. **TigerBeetle** - Measured
2. **BIBEs** - In progress
3. **ClickHouse** - Planned
4. **ClickStack** - Planned
5. **Prefect** - Planned
6. **Inference** - Planned
7. **Caddy** - Planned
8. **Vector** - Planned

TigerBeetle is the current focus. Its 72-run Locust matrix is complete, and the final report records the medians and limitations. TigerBeetle had higher median API reading throughput in all 12 tested configurations on the local host. PostgreSQL lock waits and database size remain follow-up measurements.

The [BIBEs experiment](../../bibes/) is a local Rails 8 and SQLite app that provisions isolated service namespaces in Minikube. It models parent-version reconciliation, service pinning and unpinning. A two-BIBE smoke check passes for service readiness and namespace-scoped dependency calls; UI and failure-path validation remain.

The separate [Lago wallet-ledger simulation](../../experiments/lago-wallet-ledger/) models selected credit flows as TigerBeetle transfers. It is exploratory and does not change the benchmark's measurement status.

Related: [project summary](../summary.md), [experiment practices](../practices.md)
