set shell := ["bash", "-cu"]

# --- Quality ---

# Workflow syntax and expressions; actionlint runs shellcheck on every `run:` block.
lint-workflows:
    actionlint

lint-scripts:
    shellcheck .github/scripts/*.sh

lint:
    uv run ruff check

format-check:
    uv run ruff format --check

static-checks: lint-workflows lint-scripts lint format-check

check: static-checks test

# --- Testing ---

test:
    uv run pytest

# --- Releasing ---

# Tag `main` as vX.Y.Z and move the major tag the other repos call (`@v1`) onto it: this is the rollout.
release version:
    #!/usr/bin/env bash
    set -euo pipefail
    [[ "{{ version }}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage: just release X.Y.Z" >&2; exit 1; }
    major="v$(cut -d. -f1 <<< "{{ version }}")"
    git fetch --quiet origin main
    [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "HEAD is not origin/main" >&2; exit 1; }
    # Annotated, so that a `tag.gpgSign` setup can sign them: a signed tag needs a message.
    git tag --message "v{{ version }}" "v{{ version }}"
    git tag --force --message "$major -> v{{ version }}" "$major"
    git push origin "v{{ version }}"
    git push --force origin "$major"
    echo "v{{ version }} released; $major now points at $(git rev-parse --short HEAD)"
