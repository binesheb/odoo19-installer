# Updating Odoo 19 Installer

This repository contains the deployment tooling. Updating the repository is separate from updating an existing Odoo database.

## Automatic updates

The running Odoo and PostgreSQL containers are intentionally **not** configured to silently replace themselves. Automatic image changes can introduce database migrations or compatibility changes without operator review.

For unattended infrastructure maintenance, use an external scheduler only with a controlled script that:

1. checks the `main` branch for a newer revision;
2. creates a verified backup before applying a change;
3. runs `git pull --ff-only origin main`;
4. validates the Compose configuration with `docker compose config`;
5. pulls images and restarts only after validation;
6. records the previous commit so the deployment can be rolled back.

The repository should only be auto-updated from `main`, never from feature branches.

## Manual update

From the installation directory:

```bash
git fetch origin --tags --prune
git status
git pull --ff-only origin main
docker compose config
docker compose pull
docker compose up -d
```

Before updating production Odoo data, take a database backup appropriate to the deployment. Review the incoming commits before running image or database-affecting changes.

To pin a known-good revision:

```bash
git checkout <tag-or-commit>
```

To return to the current main branch later:

```bash
git checkout main
git pull --ff-only origin main
```

## Rollback

If a repository update is incompatible, stop the stack, check out the previously recorded revision, validate the Compose file, and start the stack again. Do not delete Docker volumes during rollback unless data loss is intentional.

```bash
docker compose down
git checkout <previous-tag-or-commit>
docker compose config
docker compose up -d
```

## Versioning and releases

The project uses Semantic Versioning:

- **MAJOR**: incompatible deployment or upgrade behavior.
- **MINOR**: backward-compatible deployment capability.
- **PATCH**: backward-compatible reliability, security, or documentation fixes.

Meaningful releases should be tagged as `vMAJOR.MINOR.PATCH` and include release notes describing upgrade steps, rollback considerations, and any effect on persistent Odoo/PostgreSQL data. Documentation-only maintenance does not require a release by itself.
