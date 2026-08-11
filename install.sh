#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo ./install.sh"
  exit 1
fi

if [[ "$(. /etc/os-release; echo "$ID:$VERSION_ID")" != "ubuntu:24.04" ]]; then
  echo "This installer supports Ubuntu 24.04 LTS only."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "==> Installing prerequisites"
apt-get update
apt-get install -y ca-certificates curl gnupg postgresql

systemctl enable --now postgresql

echo "==> Adding Odoo $ODOO_VERSION repository"
install -d -m 0755 /usr/share/keyrings
curl -fsSL https://nightly.odoo.com/odoo.key \
  | gpg --dearmor --yes -o /usr/share/keyrings/odoo-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/odoo-archive-keyring.gpg] https://nightly.odoo.com/$ODOO_VERSION/nightly/deb/ ./" \
  > /etc/apt/sources.list.d/odoo.list

apt-get update
apt-get install -y odoo

# Odoo's package creates the service and PostgreSQL role. Keep a small,
# predictable local configuration for the installation.
MASTER_PASSWORD="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32)"

if [[ -f "$ODOO_CONFIG" ]]; then
  cp "$ODOO_CONFIG" "$ODOO_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
fi

cat > "$ODOO_CONFIG" <<EOF
[options]
admin_passwd = $MASTER_PASSWORD
http_port = $ODOO_PORT
proxy_mode = False
EOF

chown root:root "$ODOO_CONFIG"
chmod 640 "$ODO_CONFIG"

systemctl daemon-reload
systemctl enable --now odoo

cat > /root/odoo19-install.txt <<EOF
Odoo 19 installation completed.
URL: http://$(hostname -I | awk '{print $1}'):$ODOO_PORT
Master password: $MASTER_PASSWORD
Config: $ODOO_CONFIG
EOF
chmod 600 /root/odoo19-install.txt

echo
echo "Odoo 19 installed successfully."
cat /root/odoo19-install.txt
