# mymarvin

A Jenkins server that is entirely defined by files: no setup wizard and no
manual configuration in the web interface.

| File | Role |
|------|------|
| `Dockerfile` | Jenkins LTS image with the plugins from `plugins.txt` and `make` / `gcc` |
| `my_marvin.yml` | Jenkins Configuration as Code: users, role-based permissions, system message |
| `job_dsl.groovy` | Job DSL: the jobs created at startup |
| `docker-compose.yml` | Builds and starts the instance on port 8080 |

## Jobs

- `Tools/clone-repository`: clones a Git repository given as a parameter.
- `Tools/SEED`: generates a job for a GitHub repository. The generated job
  polls the repository every minute and runs `make fclean`, `make`,
  `make tests_run` and `make clean`.

## Roles

| Role | Permissions |
|------|-------------|
| `admin` | Full administration |
| `gorilla` | Create, configure, build and delete jobs |
| `ape` | Read and build jobs |
| `assist` | Read only |

## Run

```sh
docker compose up --build
```

Then open <http://localhost:8080>. The user passwords are set as environment
variables in the `Dockerfile`; they are demo values from the project subject.
