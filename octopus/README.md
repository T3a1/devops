# octopus

Automated deployment of a voting application on five virtual machines with
Ansible. One command installs and starts every service, and running it again
changes nothing (the playbook is idempotent).

```
            ┌──────────┐      ┌───────────┐      ┌────────────┐
 voters ──▶ │   poll   │ ───▶ │   redis   │ ───▶ │   worker   │
            │ (Python) │      │  (queue)  │      │   (Java)   │
            └──────────┘      └───────────┘      └─────┬──────┘
                                                       ▼
            ┌──────────┐                         ┌────────────┐
 viewers ─▶ │  result  │ ◀────────────────────── │ postgresql │
            │ (Node.js)│                         │    (16)    │
            └──────────┘                         └────────────┘
```

## Roles

| Role | What it does |
|------|--------------|
| `base` | Common packages on every host |
| `redis` | Installs Redis and its configuration |
| `postgresql` | Installs PostgreSQL 16 from the official repository, creates the database and the schema, configures `pg_hba.conf` |
| `poll` | Unpacks `poll.tar`, creates a Python virtualenv, installs a systemd service |
| `worker` | Unpacks `worker.tar`, builds it with Maven, installs a systemd service |
| `result` | Unpacks `result.tar`, installs Node.js dependencies, installs a systemd service |

Each service gets its own environment file. Handlers restart a service only
when its configuration has changed.

## Secrets

The database password lives in `group_vars/all.yml`, encrypted with Ansible
Vault. The vault password file, the SSH key and the real inventory are not in
the repository.

## Run

```sh
cp production.example production       # fill in the IP addresses
ansible-playbook -i production playbook.yml --ask-vault-pass
```
