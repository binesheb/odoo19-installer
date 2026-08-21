#!/usr/bin/env bash
set -Eeuo pipefail

BRANCH="main"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 is required" >&2; exit 1; }

[ -f .env ] || { echo ".env is missing; run the installer first" >&2; exit 1; }

git diff --quiet && git diff --cached --quiet || {
  echo "Refusing to update with local changes." >&2
  exit 1
}

git fetch origin "$BRANCH" --prune
LOCAL="$(git rev-parse HEAD)"
REMOTE="$(git rev-parse "origin/$BRANCH")"

if [ "$LOCAL" = "$REMOTE" ]; then
  echo "Already up to date with origin/$BRANCH."
  exit 0
fi

BASE="$(git merge-base HEAD "origin/$BRANCH")"
if [ "$LOCAL" != "$BASE" ]; then
  echo "Refusing unsafe update: local history diverged from origin/$BRANCH." >&2
  exit 1
fi

PREVIOUS="$LOCAL"
rollback() {
  echo "Update failed; restoring repository revision $PREVIOUS." >&2
  git reset --hard "$PREVIOUS"
  docker compose up -d --remove-orphans || true
}
trap rollback ERR

git merge --ff-only "origin/$BRANCH"
docker compose config >/dev/null
docker compose pull
docker compose up -d --remove-orphans

echo "$PREVIOUS" > .last-update-revision
trap - ERR
printf 'Updated safely from origin/%s. Previous revision: %s\n' "$BRANCH" "$PREVIOUS"
