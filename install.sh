#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run as root: sudo ./install.sh"
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo "ERROR: Cannot detect operating system."
  exit 1
fi

. /etc/os-release

if [[ "$ID" != "ubuntu" ]]; then
  echo "ERROR: This installer requires Ubuntu."
  echo "Detected: ${PRETTY_NAME:-unknown}"
  exit 1
fi

if [[ "${VERSION_ID:-}" != "24.04" ]]; then
  echo
  echo "WARNING: This installer is designed for Ubuntu 24.04 LTS."
  echo "Detected: ${PRETTY_NAME:-Ubuntu ${VERSION_ID:-unknown}}"
  echo "Odoo's official Odoo 19 Debian package may not officially support this Ubuntu release."
  echo "The installation will continue anyway."
  echo
fi

export DEBIAN_FRONTEND=noninteractive

echo "==> Installing prerequisites"
apt-get update
apt-get install -y ca-certificates curl gnupg openssl postgresql

systemctl enable --now postgresql

echo "==> Adding Odoo $ODOO_VERSION repository"
install -d -m 0755 /usr/share/keyrings
curl -fsSL https://nightly.odoo.com/odoo.key \
  | gpg --dearmor --yes -o /usr/share/keyrings/odoo-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/odoo-archive-keyring.gpg] https://nightly.odoo.com/$ODOO_VERSION/nightly/deb/ ./" \
  > /etc/apt/sources.list.d/odoo.list

apt-get update
apt-get install -y odoo

MASTER_PASSWORD="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)"

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
chmod 640 "$ODOO_CONFIG"

systemctl daemon-reload
systemctl enable --now odoo

SERVER_IP="$(hostname -I | awk '{print $1}')"

cat > /root/odoo19-install.txt <<EOF
Odoo 19 installation completed.
URL: http://$SERVER_IP:$ODOO_PORT
Master password: $MASTER_PASSWORD
Config: $ODOO_CONFIG
OS: $PRETTY_NAME
EOF
chmod 600 /root/odoo19-install.txt

echo
echo "========================================"
echo " Odoo 19 installation completed"
echo "========================================"
cat /root/odoo19-install.txt
