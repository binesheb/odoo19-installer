# Odoo 19 Installer

Minimal automated installer for Odoo 19 Community on Ubuntu.

## Install

```bash
git clone https://github.com/binesheb/odoo19-installer.git
cd odoo19-installer
sudo ./install.sh
```

The installer:

- Detects the Ubuntu version.
- Warns when the server is not Ubuntu 24.04 LTS, but continues.
- Installs PostgreSQL and required packages.
- Adds the Odoo 19 Community Debian repository.
- Installs Odoo 19.
- Generates a random master password.
- Creates `/etc/odoo.conf`.
- Enables and starts the Odoo systemd service.
- Saves the installation details securely in `/root/odoo19-install.txt`.

> **Compatibility note:** Odoo's official Odoo 19 Debian package is documented for Ubuntu 24.04 LTS (Noble). Other Ubuntu releases are allowed by this installer with a warning, but package compatibility is not guaranteed.

## Configuration

Edit `config.env` before installation if you need a different Odoo port, system user, or configuration path.

## Useful commands

```bash
sudo systemctl status odoo
sudo systemctl restart odoo
sudo systemctl stop odoo
sudo journalctl -u odoo -f
```

## Installation credentials

After installation, the generated master password is stored in:

```text
/root/odoo19-install.txt
```

The file is created with permissions restricted to root.

## Official documentation

[Odoo 19 On-Premise Installation](https://www.odoo.com/documentation/19.0/administration/on_premise/packages.html)
