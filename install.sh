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
  echo "Docker deployment will continue."
  echo
fi

export DEBIAN_FRONTEND=noninteractive

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "==> Docker and Compose already installed"
    return
  fi

  echo "==> Installing Docker Engine and Compose"
  apt-get update
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
}

install_docker

cd "$SCRIPT_DIR"

mkdir -p config addons

POSTGRES_PASSWORD_FILE="$SCRIPT_DIR/.env"

if [[ ! -f "$POSTGRES_PASSWORD_FILE" ]]; then
  POSTGRES_PASSWORD="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)"
  cat > "$POSTGRES_PASSWORD_FILE" <<EOF
ODOO_VERSION=$ODOO_VERSION
ODOO_PORT=$ODOO_PORT
POSTGRES_VERSION=$POSTGRES_VERSION
POSTGRES_DB=$POSTGRES_DB
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
EOF
  chmod 600 "$POSTGRES_PASSWORD_FILE"
else
  echo "==> Existing .env found; keeping existing credentials"
  source "$POSTGRES_PASSWORD_FILE"
fi

if [[ ! -f config/odoo.conf ]]; then
  ODOO_MASTER_PASSWORD="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)"

  cat > config/odoo.conf <<EOF
[options]
admin_passwd = $ODOO_MASTER_PASSWORD
db_host = db
db_port = 5432
db_user = $POSTGRES_USER
db_password = $POSTGRES_PASSWORD
http_port = 8069
proxy_mode = False
addons_path = /mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons
EOF

  chmod 640 config/odoo.conf

  cat >> "$POSTGRES_PASSWORD_FILE" <<EOF
ODOO_MASTER_PASSWORD=$ODOO_MASTER_PASSWORD
EOF
else
  echo "==> Existing Odoo configuration found; keeping existing master password"
  ODOO_MASTER_PASSWORD="$(grep '^admin_passwd' config/odoo.conf | cut -d'=' -f2- | xargs)"
fi

echo "==> Pulling Docker images"
docker compose pull

echo "==> Starting Odoo and PostgreSQL"
docker compose up -d

echo "==> Waiting for containers"
sleep 5

docker compose ps

SERVER_IP="$(hostname -I | awk '{print $1}')"

cat > /root/odoo19-install.txt <<EOF
Odoo 19 Docker installation completed.
URL: http://$SERVER_IP:$ODOO_PORT
Odoo master password: $ODOO_MASTER_PASSWORD
PostgreSQL user: $POSTGRES_USER
PostgreSQL password: $POSTGRES_PASSWORD
Project: $SCRIPT_DIR
OS: $PRETTY_NAME
EOF
chmod 600 /root/odoo19-install.txt

echo
echo "========================================"
echo " Odoo 19 Docker installation completed"
echo "========================================"
echo "URL: http://$SERVER_IP:$ODOO_PORT"
echo "Credentials: /root/odoo19-install.txt"
echo
echo "Manage with:"
echo "  docker compose ps"
echo "  docker compose logs -f odoo"
echo "  docker compose restart"
