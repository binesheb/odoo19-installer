# Odoo 19 Installer

Minimal automated installer for Odoo 19 Community on Ubuntu 24.04 LTS.

## Install

```bash
git clone https://github.com/binesheb/odoo19-installer.git
cd odoo19-installer
sudo ./install.sh
```

The script installs PostgreSQL, the official Odoo 19 Community package, generates a random master password, configures Odoo, and enables the systemd service.

## Configuration

Edit `config.env` before installation if you need a different port, user, or configuration path.

## Useful commands

```bash
sudo systemctl status odoo
sudo systemctl restart odoo
sudo journalctl -u odoo -f
```

Odoo 19's official Debian repository supports Ubuntu 24.04 LTS (Noble). See the [Odoo 19 documentation](https://www.odoo.com/documentation/19.0/administration/on_premise/packages.html).
