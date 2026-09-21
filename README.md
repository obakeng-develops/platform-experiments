# Platform Experiments

Small, reproducible experiments exploring infrastructure and platform technologies by building real systems, putting them under load, breaking them and documenting what happens.

## Method

Each experiment follows the same process:

1. Define the question and the expected behavior.
2. Build the smallest system that can answer the question.
3. Record the environment, versions and configuration.
4. Apply a repeatable workload.
5. Introduce failures and observe recovery.
6. Publish the commands, measurements and conclusions.

An experiment should include everything needed to reproduce its results. Secrets, credentials and machine-specific configuration stay out of the repository.

## Experiments

| Experiment | Status |
| --- | --- |
| [TigerBeetle](experiments/tigerbeetle/) | Measuring |
| ClickHouse | Planned |
| ClickStack | Planned |
| Prefect | Planned |
| Inference | Planned |
| Caddy | Planned |
| Vector | Planned |

## Project Knowledge

This repository uses [Lode Coding](https://fjzeit.github.io/lode) to retain decisions, conventions and lessons between development sessions. The [`lode/`](lode/) directory contains this project knowledge. [`AGENTS.md`](AGENTS.md) explains how coding agents use and maintain it.

## License

This project is licensed under the [MIT License](LICENSE).
