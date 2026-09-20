# skill-platform-workflows

The GitHub Actions workflows every repo of the skill-platform shares. One file per concern, called with
`uses: ...@v1` - so skillforge, skillsite and skillbot deploy and triage in exactly the same way, and a fix
lands in all of them at once.

| Workflow | What it does | Decision record |
|---|---|---|
| [`deploy.yml`](.github/workflows/deploy.yml) | Deploys a Dokploy compose service through the Dokploy API, waits for the deployment to end and verifies the running version. The only code that talks to Dokploy ([`deploy-dokploy.sh`](.github/scripts/deploy-dokploy.sh)). | [`release-flow.md`](https://github.com/Nachhilfe-Leon-Weimann/skillforge/blob/main/docs/specs/release-flow.md) |
| [`triage.yml`](.github/workflows/triage.yml) | Puts every issue and PR on the org project with its Module, assigns the author, moves a closed item into the current iteration, asks for a missing issue type. | [`project-intake.md`](https://github.com/Nachhilfe-Leon-Weimann/skillforge/blob/main/docs/specs/project-intake.md) |

The specs live in skillforge, the first adopter; they carry the *why*. This repo is public because a public
repo cannot call workflows from a private one.

What stays in each repo: `ci.yml` (job `check`), `build.yml` and `release.yml` (release-please, then build and
publish) - they differ per stack - plus the two callers below.

## Calling `deploy.yml`

Each repo keeps a thin `deploy.yml`: the manual entry point (`workflow_dispatch`) and what its `release.yml`
calls after a release.

```yaml
name: Deploy
run-name: Deploy v${{ inputs.version }} to production

on:
  workflow_call:
    inputs:
      version:
        required: true
        type: string
      sha:
        required: false
        default: ""
        type: string
  workflow_dispatch:
    inputs:
      version:
        description: "Released version that must be running afterwards, without leading v"
        required: true
        type: string
      dry_run:
        description: "Only verify Dokploy API access, deploy nothing"
        required: true
        default: false
        type: boolean

permissions:
  contents: read

jobs:
  deploy:
    name: Deploy
    uses: Nachhilfe-Leon-Weimann/skill-platform-workflows/.github/workflows/deploy.yml@v1
    with:
      version: ${{ inputs.version }}
      sha: ${{ inputs.sha || github.sha }}
      dry_run: ${{ inputs.dry_run || false }}
    secrets: inherit
```

Do not give the caller a `concurrency` group named `deploy-production`: the shared job holds that group, and a
caller that declared it too would wait for itself.

Configuration, all of it in the **calling** repo:

| Where | Name | Value |
|---|---|---|
| Org variable | `DOKPLOY_BASE_URL` | the Dokploy instance, HTTPS |
| Environment `production`, secret | `DOKPLOY_API_KEY` | API key of the deploying Dokploy user |
| Environment `production`, variable | `DOKPLOY_COMPOSE_ID` | id of the compose service |
| Environment `production`, variable | `HEALTH_URL` | `GET` endpoint answering `{"status": "ok", "version": "X.Y.Z"}`; leave it unset for a service without HTTP - the deployment status is then the whole verification |

The environment's deployment branches are restricted to `main`, and the job skips every other ref. The job runs
the deploy script of the ref it was called at (`job.workflow_repository` / `job.workflow_sha`), never code of
the calling repo. It does not roll back: a failed deployment or a wrong version is a red run.

## Calling `triage.yml`

```yaml
name: Triage

on:
  issues:
    types: [opened, reopened, closed]
  pull_request_target:
    types: [opened, reopened, closed]

permissions: {}

jobs:
  triage:
    name: Triage
    uses: Nachhilfe-Leon-Weimann/skill-platform-workflows/.github/workflows/triage.yml@v1
    permissions:
      issues: write
      pull-requests: write
    secrets: inherit
```

A called workflow can only get permissions its caller grants, hence the `permissions` on the calling job.

Configuration in the calling repo: the repository variable `PROJECT_MODULE` - the repo's option of the project
field *Module* (`forge`, `site`, `bot`). Org-level and shared by all repos: the variable `RELEASE_APP_CLIENT_ID`
and the secret `RELEASE_APP_PRIVATE_KEY` of the App `skill-platform-release`, which has to be installed on the
calling repo.

`issues` and `pull_request_target` run the caller from its `main` with the App key, for anyone who opens an
issue or a PR. That is safe only while the caller stays these few lines and `triage.yml` never checks out code
and never puts event data into a `run:` block - [`test_workflows.py`](tests/test_workflows.py) guards the
latter two.

## Versions

Releases are git tags on `main`: an immutable `vX.Y.Z` per release and the moving major tag `v1` the other
repos call. Moving `v1` **is the rollout** - every repo picks the change up on its next run, without a PR.

```
just release 1.2.3        # on an up-to-date main: tags v1.2.3, moves v1, pushes both
```

- Try a change before releasing it: point one caller at the branch (`...@my-branch`) in a PR of that repo.
  `deploy.yml` only runs for `main`, so its proof is a `dry_run` dispatch after the release.
- A change callers have to follow (a renamed input, a new required variable) is a new major: tag `v2.0.0` and
  `v2`, then move the callers one by one. `v1` stays where it is.
- Roll back by moving the major tag onto the earlier release: `git tag -f v1 v1.2.2 && git push -f origin v1`.

## Development

`just check` - actionlint (with shellcheck on every `run:` block), shellcheck on the script, ruff, and the
tests: the deploy script against an in-process fake of the Dokploy API, and the rules the workflows must keep.
CI runs the same as the job `check`, the required check of `main`.

Needs `just`, `uv`, `actionlint`, `shellcheck`, `curl` and `jq`.
