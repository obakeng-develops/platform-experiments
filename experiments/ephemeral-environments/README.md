# Ephemeral Environments

**Status:** Local simulation running on Minikube.

This experiment reworks the idea from [Buffer's BIBEs](https://peteremil.com/buffers-bibes/) as a small Rails app backed by a local Kubernetes cluster. I call each isolated copy an ephemeral environment.

The question is: can each engineer get an isolated copy of the backend, while services they have not changed continue to follow a parent environment?

## What the simulation does

Each ephemeral environment has its own Kubernetes namespace and one deployment and service for each logical backend service. Kubernetes service discovery resolves a service name inside the caller's namespace.

An environment starts with the versions from its parent. Deploying a service into an environment changes only that service and pins it there. Parent releases update every unpinned copy when reconciliation runs.

The demo includes two engineers. Alice's `posts` service is pinned at `9.0.0`. Staging and Bob's `posts` service run `2.5.0`.

This simulation uses one small HTTP image for all workload services. The version is reported through an environment variable; different service versions do not contain different application code. The dashboard, release state and Kubernetes rollouts are real, while the service behavior is intentionally small.

## Running locally

Requirements:

- macOS or Linux
- Ruby 3.3 or newer
- Rails 8.1
- Docker
- kubectl
- Minikube
- Go 1.27 to build the toy service image

The first local run used Ruby 3.3.4, Rails 8.1.4, SQLite 3.51.0, Go 1.27.1, Docker 29.8.1, Minikube 1.39.0 and Kubernetes 1.37.0 on macOS. The Rails and Go dependencies are locked in `Gemfile.lock` and `service/go.mod`.

Start Minikube, build and load the service image, prepare SQLite and create the demo environments:

```sh
bin/setup-local
```

Start the Rails app:

```sh
bin/rails server -p 3002
```

Open <http://localhost:3002>.

`bin/setup-local` uses the Docker driver and gives Minikube 4 CPUs and 6 GiB of memory. The app and verification script target the `minikube` kubectl context explicitly, even if another context is active. It creates Alice's and Bob's staging environments and applies the initial demo state. Run `bin/demo` to restore Alice and Bob's environments after experimenting. It leaves any other environments alone.

## Trying the deployment flow

1. Open Alice's environment. `posts` is pinned at `9.0.0`; the other services follow staging.
2. On the dashboard, deploy a new `posts` version to staging, such as `2.6.0`.
3. Open Bob's environment. Reconciliation updates Bob's `posts` service to `2.6.0`.
4. Open Alice's environment. Her pinned `posts` service remains at `9.0.0`.
5. Choose **Follow parent** on Alice's `posts` service to unpin it and sync it to staging.

To check pod readiness and service-to-service calls from inside each namespace:

```sh
bin/verify
```

The check asks each service for its dependency tree and confirms every dependency responds from the same environment namespace.

To inspect the cluster directly:

```sh
kubectl get namespaces
kubectl get deployments,services -n ephemeral-alice-staging
kubectl get deployments,services -n ephemeral-bob-staging
```

## Design notes

The UI uses Campsite's neutral scale and component patterns with the Nova shadcn style, a lime theme, Inter typography and Lucide icons. The inline Lucide and Feather icon notices are in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). The dashboard leads with the staging release scenario; each environment card highlights `posts` and keeps the other service rows behind a disclosure.

Copy follows *On Writing Well*. Layout decisions use *Design Is Storytelling* and *Don't Make Me Think*. The first rendered screen gets a critique with the Interface-Craft design critique method.

## Limits

- This runs on one local Minikube cluster. It does not test production load or cloud networking.
- The database and cache are toy HTTP services, not real datastores.
- Every service uses the same workload image. A version change is a real Kubernetes rollout but does not replace different application code.
- Namespace DNS isolation is provided by Kubernetes. This simulation does not implement Buffer's parameter-resolution tooling or DNS automation.

## License

This experiment is part of [Platform Experiments](../../README.md), licensed under the MIT License.
