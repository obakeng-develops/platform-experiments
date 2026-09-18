# Experiment Practices

Experiments answer a stated question with a system that another person can reproduce. Each experiment records the system and tool versions, runtime environment, configuration, setup commands, workload, failure cases, measurements and conclusions.

Use the smallest system that can answer the question. Automate any setup, workload or failure step where manual variation could change the result. Keep raw measurements or links to them beside the interpretation so conclusions can be checked.

Do not commit secrets, credentials, customer data or machine-specific configuration. Use documented environment variables and checked-in examples when configuration is required.

Create an experiment directory when work begins. Future experiments remain in the [roadmap](plans/experiment-roadmap.md) until then.

Related: [summary](summary.md), [terminology](terminology.md)
