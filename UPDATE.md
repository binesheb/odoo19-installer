# Updating Odoo 19 Installer

This repository contains deployment tooling. Updating the repository is separate from updating an existing Odoo database.

## Safe manual update

Run the bundled updater from the installation directory:

```bash
bash scripts/update.sh
```

The updater only accepts fast-forward changes from `origin/main`. It refuses local changes or diverged history, validates Docker Compose, refreshes declared images, restarts the stack, and records the previous repository revision in `.last-update-revision` for recovery.

Before applying production changes, take a database backup appropriate to the deployment. Review incoming changes when they may affect images, addons, or database compatibility.

## Automatic updates

Automatic repository updates must use the same bundled updater and **only** track `origin/main`, never feature or development branches.

Because Odoo and PostgreSQL changes can involve database migrations or compatibility changes, schedule automatic updates only when the host has an appropriate backup policy and operational monitoring. A timer or service may run:

```bash
/path/to/odoo19-installer/scripts/update.sh
```

The script validates the update path and restores the previous repository revision if the update command fails. Docker volumes are never deleted by the updater or rollback path.

## Rollback

If a deployment still needs manual recovery, use the recorded revision:

```bash
PREVIOUS=$(cat .last-update-revision)
docker compose down
git reset --hard "$PREVIOUS"
docker compose config
docker compose up -d --remove-orphans
```

Do not delete Docker volumes during rollback unless data loss is intentional.

## Versioning and releases

The project uses Semantic Versioning:

- **MAJOR**: incompatible deployment or upgrade behavior.
- **MINOR**: backward-compatible deployment capability.
- **PATCH**: backward-compatible reliability or security fixes.

Meaningful releases should be tagged as `vMAJOR.MINOR.PATCH` and include upgrade steps, rollback considerations, and any effect on persistent Odoo/PostgreSQL data. Documentation-only maintenance does not require a release by itself.
