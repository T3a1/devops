# chocolatine

A GitHub Actions workflow for C projects, in
[`.github/workflows/chocolatine.yml`](.github/workflows/chocolatine.yml).
On each push or pull request it:

1. skips branches named `ga-ignore-*` and the mirror repository itself;
2. runs the Epitech coding style checker and turns each error into a GitHub annotation;
3. builds the project with `make` and checks that the expected binaries exist;
4. runs `make tests_run`;
5. on push, mirrors the repository to `MIRROR_URL` over SSH (key in the `GIT_SSH_PRIVATE_KEY` secret).

`code.c` and `Makefile` are a minimal project used to test the pipeline.

To use it, copy the workflow to `.github/workflows/` at the root of a
repository and set `MIRROR_URL` and `EXECUTABLES`.
