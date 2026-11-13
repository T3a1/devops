# bernstein

Deployment of a three-service voting application on Kubernetes, from source
code to a public cluster on Azure (AKS). It is the same application as
[octopus](../octopus), which deploys it on virtual machines with Ansible.

```
          Internet                                                      Internet
             │ public IP (LoadBalancer)                                    │ public IP (LoadBalancer)
             ▼                                                             ▼
┌──────────────────────────────── namespace "poll" ─────────────────────────────────────┐
│ ┌──────────┐ RPUSH ┌───────────┐ BLPOP ┌──────────┐ UPSERT ┌────────────┐ SELECT ┌──────────┐ │
│ │ poll ×2+ │──────►│   redis   │──────►│  worker  │───────►│ postgresql │◄───────│ result ×2│ │
│ │ + HPA    │       │ + PVC 1Gi │       │          │        │ + PVC 2Gi  │        │          │ │
│ └──────────┘       └───────────┘       └──────────┘        └────────────┘        └──────────┘ │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

| Component | Kubernetes objects | Exposure | Replicas | Storage |
|-----------|--------------------|----------|----------|---------|
| poll (Python) | Deployment, HPA, PodDisruptionBudget | LoadBalancer | 2 to 5 (CPU 70 %) | — |
| result (Node.js) | Deployment, PodDisruptionBudget | LoadBalancer, ClientIP affinity | 2 | — |
| worker (Java) | Deployment | none | 1 | — |
| redis | StatefulSet | ClusterIP | 1 | PVC 1 Gi, append-only |
| postgresql 18 | StatefulSet | ClusterIP | 1 | PVC 2 Gi |

## Design choices

- **Kustomize** rather than Helm: the manifests in `k8s/base/` read as they are,
  only the image names change between targets.
- **Zero-downtime updates**: images are tagged with the Git commit, rolling updates
  with `maxUnavailable: 0`, `minReadySeconds`, a `preStop` hook that takes the pod
  out of the load balancer before it stops, and PodDisruptionBudgets.
  `scripts/test-no-downtime.sh` polls both pages during a deployment and counts errors.
- **Health checks**: startup, readiness and liveness probes on `/healthz` and
  `/readyz`, so a pod only gets traffic once its dependencies answer.
- **Availability**: at least two replicas of each public page, spread over the
  nodes (`topologySpreadConstraints`); `poll` scales on CPU.
- **Session affinity** on `result`, whose Socket.IO long polling needs every
  request of a browser to reach the same pod.
- **Security**: no secret in the repository (`.env` → Kubernetes Secret),
  password-protected Redis, databases reachable only inside the cluster,
  NetworkPolicies between pods, dropped Linux capabilities, `seccomp`.
- **Resources**: requests on every container, memory limits, a CPU limit on Redis.
- **Cost control**: the AKS control plane on the free tier, and a script that
  stops the nodes between sessions.

## Repository

| Path | Role |
|------|------|
| `poll/`, `worker/`, `result/` | Source code and Dockerfile of each service (provided with the subject, see [APPLICATION.md](APPLICATION.md)) |
| `schema.sql` | Database schema, applied when PostgreSQL first starts |
| `k8s/base/` | Kubernetes manifests (Kustomize) |
| `k8s/policies/` | NetworkPolicies, applied on AKS |
| `compose.yml` | Local run with Docker Compose |
| `kind-config.yaml` | Local three-node cluster with kind |
| `scripts/azure-infra.sh` | Create, start, stop or destroy the Azure resources (resource group, ACR, AKS) |
| `scripts/deploy.sh` | Build, push and deploy (`azure` or `local`) |
| `scripts/status.sh` | Overview: nodes, pods, resource usage, Redis queue, votes |

## Run

Requires Docker with `buildx`, `kubectl`, and `az` (Azure) or `kind` (local).

```sh
cp .env.example .env                 # passwords, Azure subscription and registry name
```

On Azure:

```sh
az login
scripts/azure-infra.sh create        # resource group, container registry, AKS cluster
scripts/deploy.sh azure              # build for amd64, push, deploy, print both URLs
scripts/azure-infra.sh stop          # stop the nodes at the end of a session
```

Locally:

```sh
scripts/local-cluster.sh create
scripts/deploy.sh local
kubectl -n poll port-forward svc/poll 8080:80
```

Or without Kubernetes: `docker compose up -d --build`.

## Team

Léandre Fouret, [David Caron](https://github.com/sojournerfr)
