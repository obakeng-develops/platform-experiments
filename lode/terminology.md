# Terminology

- **Experiment** - A reproducible investigation designed to answer a specific technical question.
- **System under test** - The technology and supporting components being exercised.
- **Workload** - The repeatable operations applied to the system under test.
- **Failure case** - A controlled fault introduced to observe system behavior and recovery.
- **Observation** - A recorded event or measurement produced while running an experiment.
- **Conclusion** - A claim supported by published observations.
- **Ephemeral environment** - An engineer's isolated backend copy, implemented here as a Kubernetes namespace with one deployment and service per logical service. The model is based on Buffer's BIBEs.
- **Parent environment** - The staging or prod version map an ephemeral environment copies and follows.
- **Pinned service** - A service deployed to an ephemeral environment at an engineer-selected version; reconciliation leaves it unchanged until it is unpinned.
- **Reconciliation** - Updating each unpinned service to the version currently recorded for its parent environment.
- **Namespace-scoped discovery** - Kubernetes service DNS resolves a service name within the caller's namespace, keeping same-named services in separate ephemeral environments isolated.

Related: [practices](practices.md)
