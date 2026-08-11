# Odoo 19 Docker Installer

Minimal automated Docker deployment for Odoo 19 Community and PostgreSQL on Ubuntu.

## Install

```bash
git clone https://github.com/binesheb/odoo19-installer.git
cd odoo19-installer
sudo ./install.sh
```

The installer:

- Detects the Ubuntu version.
- Warns when the server is not Ubuntu 24.04 LTS, but continues.
- Installs Docker Engine and Docker Compose if needed.
- Creates an isolated PostgreSQL container.
- Creates an Odoo 19 container.
- Creates persistent Docker volumes for PostgreSQL and Odoo data.
- Generates secure PostgreSQL and Odoo master passwords.
- Starts the stack automatically.
- Saves installation credentials securely in `/root/odoo19-install.txt`.

## Architecture

```text
Ubuntu Server
│
└── Docker
    ├── Odoo 19
    │   └── Port 8069
    │
    └── PostgreSQL 15
```

Odoo and PostgreSQL are isolated from the host operating system. Data is stored in Docker-managed persistent volumes.

## Configuration

Edit `config.env` before installation to change the Odoo version, port, PostgreSQL version, database name, or database user.

The installer creates a local `.env` containing generated credentials. It is excluded from Git.

## Useful commands

Run these from the repository directory:

```bash
docker compose ps
docker compose logs -f odoo
docker compose logs -f db
docker compose restart
docker compose stop
docker compose start
docker compose down
```

To remove containers without deleting persistent data:

```bash
docker compose down
```

Do **not** use `docker compose down -v` unless you intentionally want to delete the PostgreSQL and Odoo data volumes.

## Custom addons

Place custom Odoo addons in:

```text
addons/
```

They are mounted into the Odoo container at `/mnt/extra-addons`.

## Installation credentials

After installation:

```text
/root/odoo19-install.txt
```

The file contains the Odoo master password and PostgreSQL credentials and is restricted to root.

## Compatibility

The Docker deployment is not blocked by the Ubuntu version. Ubuntu 24.04 LTS is the recommended production host. Other Ubuntu releases receive a warning and installation continues.

## Official documentation

[Odoo 19 Documentation](https://www.odoo.com/documentation/19.0/)

[Docker Documentation](https://docs.docker.com/)
