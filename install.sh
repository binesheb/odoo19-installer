#!/usr/bin/env bash
set -euo pipefail

# Keep generated credentials private for the entire installer process.
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Read simple KEY=value configuration without executing the file as shell code.
read_env_value() {
  local file="$1"
  local key="$2"
  awk -v key="$key" '
    index($0, key "=") == 1 {
      if (found) exit 2
      value = substr($0, length(key) + 2)
      found = 1
    }
    END {
      if (found) print value
      else exit 1
    }
  ' "$file"
}

if [[ ! -f "$SCRIPT_DIR/config.env" ]]; then
  echo "ERROR: Missing configuration file: $SCRIPT_DIR/config.env"
  exit 1
fi

for variable in ODOO_VERSION ODOO_PORT POSTGRES_VERSION POSTGRES_DB POSTGRES_USER; do
  if ! value="$(read_env_value "$SCRIPT_DIR/config.env" "$variable")"; then
    echo "ERROR: Required configuration value is missing or duplicated: $variable"
    echo "Check config.env and provide exactly one KEY=value entry."
    exit 1
  fi
  printf -v "$variable" '%s' "$value"
done

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run as root: sudo ./install.sh"
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo "ERROR: Cannot detect operating system."
  exit 1
fi

# shellcheck disable=SC1091
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

required_config=(ODOO_VERSION ODOO_PORT POSTGRES_VERSION POSTGRES_DB POSTGRES_USER)
for variable in "${required_config[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "ERROR: Required configuration value is missing: $variable"
    echo "Check config.env and provide a non-empty value."
    exit 1
  fi
done

if ! [[ "$ODOO_PORT" =~ ^[0-9]+$ ]] || (( ODOO_PORT < 1 || ODOO_PORT > 65535 )); then
  echo "ERROR: ODOO_PORT must be a TCP port between 1 and 65535."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "==> Docker and Compose already installed"
    systemctl enable --now docker
    return
  fi

  echo "==> Installing Docker Engine and Compose"
  apt-get update
  apt-get install -y ca-certificates curl openssl

  # Prefer Docker's official repository on supported Ubuntu releases.
  # On other Ubuntu releases, fall back to Ubuntu's packaged Docker Engine.
  DOCKER_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  DOCKER_REPO_OK=false

  if [[ "$DOCKER_CODENAME" == "jammy" || "$DOCKER_CODENAME" == "noble" || "$DOCKER_CODENAME" == "resolute" ]]; then
    if curl -fsS --head "https://download.docker.com/linux/ubuntu/dists/$DOCKER_CODENAME/Release" >/dev/null; then
      DOCKER_REPO_OK=true
    fi
  fi

  if [[ "$DOCKER_REPO_OK" == true ]]; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $DOCKER_CODENAME
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    echo "WARNING: Docker's official repository is not available for Ubuntu $DOCKER_CODENAME."
    echo "Using Ubuntu's Docker packages instead."
    apt-get update
    apt-get install -y docker.io docker-compose-v2
  fi

  systemctl enable --now docker
}

install_docker

cd "$SCRIPT_DIR"

mkdir -p config addons

POSTGRES_PASSWORD_FILE="$SCRIPT_DIR/.env"

if [[ ! -f "$POSTGRES_PASSWORD_FILE" ]]; then
  POSTGRES_PASSWORD="$(openssl rand -hex 16)"
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
  for variable in ODOO_VERSION ODOO_PORT POSTGRES_VERSION POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD; do
    if ! value="$(read_env_value "$POSTGRES_PASSWORD_FILE" "$variable")"; then
      echo "ERROR: Existing .env has a missing or duplicated value: $variable"
      echo "Refusing to continue with ambiguous credentials."
      exit 1
    fi
    printf -v "$variable" '%s' "$value"
  done
fi

if [[ ! -f config/odoo.conf ]]; then
  ODOO_MASTER_PASSWORD="$(openssl rand -hex 16)"

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
echo "==> Starting Odoo and PostgreSQL and waiting for readiness"
docker compose up -d --wait --wait-timeout 120

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
