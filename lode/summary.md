# Summary

Platform Experiments is a collection of small, reproducible investigations into infrastructure and platform technologies. Each experiment builds a real system, applies a documented workload, introduces failures and publishes the commands, measurements and conclusions. The TigerBeetle experiment has a Rails electricity-meter API, PostgreSQL and TigerBeetle ledger implementations and a Locust workload. Its final 72-run matrix found higher median API reading throughput for TigerBeetle in all 12 tested configurations on one local host. PostgreSQL lock waits and database size remain to be measured. ClickHouse, ClickStack, Prefect, Inference, Caddy and Vector follow in that order.

Related: [practices](practices.md), [experiment roadmap](plans/experiment-roadmap.md)
