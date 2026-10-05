# Terminology

- **Experiment** - A reproducible investigation designed to answer a specific technical question.
- **System under test** - The technology and supporting components being exercised.
- **Workload** - The repeatable operations applied to the system under test.
- **Failure case** - A controlled fault introduced to observe system behavior and recovery.
- **Observation** - A recorded event or measurement produced while running an experiment.
- **Conclusion** - A claim supported by published observations.
- **BIBE** - An engineer's isolated copy of the backend, implemented here as a Kubernetes namespace with one deployment and service per logical service.
- **Parent environment** - The staging or prod version map a BIBE copies and follows.
- **Pinned service** - A service deployed to a BIBE at an engineer-selected version; reconciliation leaves it unchanged until it is unpinned.
- **Reconciliation** - Updating each unpinned BIBE service to the version currently recorded for its parent environment.
- **Namespace-scoped discovery** - Kubernetes service DNS resolves a service name within the caller's namespace, keeping same-named services in separate BIBEs isolated.

Related: [practices](practices.md)
