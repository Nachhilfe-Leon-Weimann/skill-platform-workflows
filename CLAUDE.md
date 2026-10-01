# CLAUDE.md

Anchor for AI assistants and quick onboarding. What the workflows do and how they are called is in the
[`README`](README.md); the *why* lives in skillforge's specs
([`release-flow.md`](https://github.com/Nachhilfe-Leon-Weimann/skillforge/blob/main/docs/specs/release-flow.md),
[`project-intake.md`](https://github.com/Nachhilfe-Leon-Weimann/skillforge/blob/main/docs/specs/project-intake.md)).

## Commands

- `just check` - actionlint, shellcheck, ruff, tests. **Keep green before every commit.**
- `just test` - only the tests.
- `just release X.Y.Z` - tag `main` and move the major tag. This rolls the change out to every calling repo;
  Leon runs it, not an agent.

## Layout

```
.github/workflows/   deploy.yml, triage.yml (shared, `workflow_call` only), ci.yml (this repo's own, job `check`)
.github/scripts/     deploy-dokploy.sh (the only code that talks to Dokploy)
.github/actionlint.yaml   one ignore for `job.workflow_*`, which actionlint does not know yet
tests/               test_deploy_dokploy.py (the script against a fake Dokploy), test_workflows.py (the rules below)
```

## Conventions

- **Write everything in English.** Conventional commits; merge with `gh pr merge <n> --squash --delete-branch --auto`.
- **Every change here reaches three repos** once `v1` moves. A shared workflow's inputs, the variables and
  secrets it reads, and its job names are an interface: changing one of them is a new major (README, *Versions*).
- **Nothing repo-specific in a shared workflow.** What differs between the repos is configuration of the
  calling repo (`vars`, the `production` environment), never a line in a file here.
- **Pin every action by full SHA with a version comment**; Dependabot keeps them current.
- **`triage.yml` never checks out code and never puts `${{ ... }}` into a `run:` block** - its callers run on
  `pull_request_target` with the App key. Event data reaches a script through `env:` only.
- **`deploy.yml` checks out this repo at its own ref and nothing else** - the caller's `compose.yml` comes through
  the API as data - and keeps its concurrency group on the job. Never print or echo secrets; the Dokploy API key goes through a curl config file.
- **No rollback, digest pinning, attestations or notifications** - non-goals of the release flow, not omissions.
- A shared workflow only has the `workflow_call` trigger; it cannot be tried in this repo. The tests are the
  safety net, a `dry_run` dispatch of a caller's `deploy.yml` is the live proof.
