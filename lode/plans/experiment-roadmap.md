# Experiment Roadmap

The experiments are planned in this order:

1. **TigerBeetle** - Measuring
2. **ClickHouse** - Planned
3. **ClickStack** - Planned
4. **Prefect** - Planned
5. **Inference** - Planned
6. **Caddy** - Planned
7. **Vector** - Planned

TigerBeetle is the current focus. Its 72-run Locust matrix is complete, and the final report records the medians and limitations. TigerBeetle had higher median API reading throughput in all 12 tested configurations on the local host. PostgreSQL lock waits and database size remain follow-up measurements.

The separate [Lago wallet-ledger simulation](../../experiments/lago-wallet-ledger/) models selected credit flows as TigerBeetle transfers. It is exploratory and does not change the benchmark's measurement status.

Related: [project summary](../summary.md), [experiment practices](../practices.md)
