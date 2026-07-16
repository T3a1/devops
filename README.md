# DevOps

A collection of technical projects built as part of the DevOps curriculum at Epitech. Each subfolder is a standalone project exploring different facets of DevOps practice — from automating CI/CD infrastructure to provisioning and deploying a multi-service application across a fleet of machines.

## Domain Overview

DevOps, as covered by these projects, focuses on treating infrastructure and delivery pipelines as code: automating the setup of tooling, provisioning servers reproducibly, and orchestrating multi-service deployments without manual, one-off configuration. In practice here, that means:

- **Infrastructure as Code (IaC)** — describing servers, services, and their configuration declaratively (Ansible roles/playbooks) instead of configuring machines by hand.
- **Configuration as Code (CasC)** — bootstrapping tooling (Jenkins) fully from version-controlled configuration files, so an entire CI server can be rebuilt identically from scratch.
- **Containerization** — packaging tools and their dependencies into Docker images/Compose stacks for reproducible, portable environments.
- **Secrets management** — keeping sensitive values (database passwords, credentials) out of plain text using encryption (Ansible Vault) rather than committing them in the clear.
- **Multi-tier service orchestration** — coordinating the provisioning of several interdependent services (queue, workers, database, cache, front end) across separate hosts in the correct order.

## Projects

### [`[2nd year] myMarvin`](./%5B2nd%20year%5D%20myMarvin/)

A fully code-defined Jenkins CI server. A `Dockerfile` builds a Jenkins image with a fixed plugin set (`plugins.txt`), and Jenkins Configuration as Code (JCasC) provisions the entire instance on startup — security realm, users, role-based authorization, and system message — all from `my_marvin.yml`. Job definitions themselves (a repository-cloning job and a parametrized "SEED" job that generates build pipelines for student projects) are created via Job DSL (`job_dsl.groovy`) rather than clicked together in the UI. `docker-compose.yml` ties it all together as a single runnable stack.

### [`[2nd year] Octopus`](./%5B2nd%20year%5D%20Octopus/)

An Ansible-based deployment of a distributed voting-style application across six provisioned VMs: a `poll` front end, a `worker` service, a `result` front end, backed by `redis` (queue) and `postgresql` (persistent storage), all sitting on a common `base` role. A single `playbook.yml` targets each host group in turn, and each `roles/*` directory installs the right language runtime (Python/venv, Java/Maven, Node.js), unpacks the pre-built service archive (`poll.tar`, `worker.tar`, `result.tar`), writes its environment file, and registers it as a `systemd` service with restart handlers. Sensitive values (e.g. the PostgreSQL password) are pulled from an Ansible Vault-encrypted `group_vars/all.yml` rather than stored in plain text.

## Common Threads

Both projects, despite operating at different layers (CI tooling vs. application deployment), share the same underlying DevOps approach:

- Every environment is defined by version-controlled configuration, not manual setup — Jenkins via JCasC/Job DSL, VMs via Ansible roles.
- Services are composed from small, single-responsibility units (one role per service, one job per pipeline) rather than monolithic setup scripts.
- Secrets and credentials are handled deliberately (environment variables, Ansible Vault) rather than hardcoded into application logic.
- The end goal in both cases is a fully reproducible environment that can be torn down and rebuilt from the repository alone.

## License

MIT License — see [`LICENSE`](./LICENSE). Copyright (c) 2026 Léandre Fouret.
