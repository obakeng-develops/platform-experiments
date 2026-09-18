# Agent Instructions

This repository uses the [Lode Coding](https://fjzeit.github.io/lode) method to retain project knowledge across development sessions.

## Starting A Session

Before searching the repository or changing files, read:

1. `lode/lode-map.md`
2. `lode/summary.md`
3. `lode/terminology.md`
4. Any topic files linked by the map that apply to the task

Briefly show the relevant domain knowledge before starting work.

## Working With The Lode

- Treat the implementation and measured experiment results as the source of truth.
- Keep lode documents focused on the current state. Do not use them as changelogs.
- Record durable decisions, constraints, terminology and lessons that future sessions need.
- Keep temporary notes and handovers in `lode/tmp/`, which is ignored by Git.
- Update the relevant lode files after an accepted change alters repository structure, experiment practices or known behavior.
- Update `lode/lode-map.md` whenever lode files are added, moved or removed.
- Keep each lode file focused on one topic and link related files with relative paths.
- If a lode document conflicts with the repository, explain the difference and propose a correction.

## Running Experiments

- Discuss the question, expected behavior and measurement plan before implementation.
- Prefer the smallest system that can answer the question.
- Pin tool and service versions used to produce results.
- Automate setup, workload and failure injection when repetition affects the result.
- Record commands, environment details, measurements, failures and conclusions in the experiment directory.
- Never commit credentials, tokens or customer data.
- Add an experiment directory when work on that experiment begins. Do not create empty future scaffolding.

The human owns the code, experiments and final decisions. Agents provide context, implementation and verification.
