#!/usr/bin/env bash
set -euo pipefail

log() { echo "[firstboot] $*"; }

PROV=/boot/provision.env
if [ -f "$PROV" ]; then
  log "Loading $PROV"
  # shellcheck disable=SC1090
  . "$PROV"
else
  log "No /boot/provision.env found; using defaults/placeholders"
fi

SERIAL=$(awk '/Serial/ {print $3}' /proc/cpuinfo | tr '[:lower:]' '[:upper:]' || true)
SHORT="${SERIAL: -6}"
HOSTNAME_VALUE="${HOSTNAME_VALUE:-SC-${SERIAL}}"

log "Setting hostname to ${HOSTNAME_VALUE}"
hostnamectl set-hostname "$HOSTNAME_VALUE"
if grep -q '^127\.0\.1\.1' /etc/hosts; then
  sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t${HOSTNAME_VALUE}/" /etc/hosts
else
  echo -e "127.0.1.1\t${HOSTNAME_VALUE}" >> /etc/hosts
fi

# Create a login user for PM2 to store its state
if ! id controller >/dev/null 2>&1; then
  log "Creating user 'controller' with home"
  useradd -m -s /bin/bash controller
fi

# Regenerate SSH host keys if missing
if ! ls /etc/ssh/ssh_host_* >/dev/null 2>&1; then
  log "Regenerating SSH host keys"
  dpkg-reconfigure openssh-server
  systemctl restart ssh || true
fi

# Tailscale (optional)
if [ "${ENABLE_TAILSCALE:-yes}" = "yes" ]; then
  if ! command -v tailscale >/dev/null 2>&1; then
    log "Installing Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  if [ -n "${TAILSCALE_AUTH_KEY:-}" ]; then
    log "Bringing up Tailscale"
    tailscale up --authkey "${TAILSCALE_AUTH_KEY}" --hostname "${HOSTNAME_VALUE}" || true
  else
    log "TAILSCALE_AUTH_KEY not set; skipping 'tailscale up'"
  fi
fi

APP_DIR=/opt/pi-controller-nodejs
REPO_URL="${REPO_URL:-https://github.com/estconsulting/pi-controller-nodejs.git}"
REPO_REF="${REPO_REF:-main}"

if [ ! -d "$APP_DIR/.git" ]; then
  log "Cloning repo: $REPO_URL"
  git clone --branch "$REPO_REF" --depth 1 "$REPO_URL" "$APP_DIR"
else
  log "Updating repo"
  git -C "$APP_DIR" fetch --depth 1 origin "$REPO_REF" && git -C "$APP_DIR" reset --hard "origin/$REPO_REF"
fi

log "Installing production npm deps"
cd "$APP_DIR"
npm install --omit=dev --no-optional || npm ci --omit=dev --no-optional || true

# Write .env into the app directory (what your app expects)
ENV_FILE_APP="$APP_DIR/.env"
: > "$ENV_FILE_APP"
{
  echo "NODE_ENV=${NODE_ENV:-production}"
  echo "NODE_PORT=${NODE_PORT:-3000}"
  echo "ENCRYPTION_KEY=${ENCRYPTION_KEY:-CHANGE_ME}"
  echo "LOWDB_DB_FILE=${LOWDB_DB_FILE:-$APP_DIR/data/pi-controller-db.json}"
  echo "SQLITE_DB_FILE=${SQLITE_DB_FILE:-$APP_DIR/data/pi-controller.db}"
  echo "WEB_SOCKET_HOST=${WEB_SOCKET_HOST:-https://api.intelliguardsa.co.za}"
  echo "WEB_SOCKET_PATH=${WEB_SOCKET_PATH:-/controller}"
} >> "$ENV_FILE_APP"
chmod 640 "$ENV_FILE_APP"

# Ensure data dir & ownership
mkdir -p "$APP_DIR/data"
chown -R controller:controller "$APP_DIR" "$APP_DIR/data" "$ENV_FILE_APP"

# Stop/disable the systemd unit if present; PM2 will manage the app
if systemctl list-unit-files | grep -q '^pi-controller.service'; then
  log "Disabling pi-controller.service in favor of PM2"
  systemctl stop pi-controller.service || true
  systemctl disable pi-controller.service || true
fi

# Configure PM2 for the 'controller' user
log "Setting up PM2 under 'controller'"
# Ensure pm2 is on PATH for the user and create an ecosystem file
ECO=/home/controller/ecosystem.config.js
cat > "$ECO" <<'EOF'
module.exports = {
  apps: [
    {
      name: "pi-controller-nodejs",
      script: "/opt/pi-controller-nodejs/dist/app.js",
      node_args: "--trace-warnings --expose-gc",
      time: true,
      cwd: "/opt/pi-controller-nodejs",
      env: {
        NODE_ENV: process.env.NODE_ENV || "production",
        NODE_PORT: process.env.NODE_PORT || "3000",
        ENCRYPTION_KEY: process.env.ENCRYPTION_KEY || "CHANGE_ME",
        LOWDB_DB_FILE: process.env.LOWDB_DB_FILE || "/opt/pi-controller-nodejs/data/pi-controller-db.json",
        SQLITE_DB_FILE: process.env.SQLITE_DB_FILE || "/opt/pi-controller-nodejs/data/pi-controller.db",
        WEB_SOCKET_HOST: process.env.WEB_SOCKET_HOST || "https://api.intelliguardsa.co.za",
        WEB_SOCKET_PATH: process.env.WEB_SOCKET_PATH || "/controller"
      }
    }
  ]
};
EOF
chown controller:controller "$ECO"

# Export env for PM2 session by appending to controller's profile
PROFILE=/home/controller/.profile
touch "$PROFILE"
chown controller:controller "$PROFILE"
{
  echo 'export NODE_ENV="${NODE_ENV:-production}"'
  echo 'export NODE_PORT="${NODE_PORT:-3000}"'
  echo 'export ENCRYPTION_KEY="${ENCRYPTION_KEY:-CHANGE_ME}"'
  echo 'export LOWDB_DB_FILE="${LOWDB_DB_FILE:-/opt/pi-controller-nodejs/data/pi-controller-db.json}"'
  echo 'export SQLITE_DB_FILE="${SQLITE_DB_FILE:-/opt/pi-controller-nodejs/data/pi-controller.db}"'
  echo 'export WEB_SOCKET_HOST="${WEB_SOCKET_HOST:-https://api.intelliguardsa.co.za}"'
  echo 'export WEB_SOCKET_PATH="${WEB_SOCKET_PATH:-/controller}"'
} >> "$PROFILE"

# Create PM2 startup service for 'controller'
pm2 startup systemd -u controller --hp /home/controller >/dev/null 2>&1 || true

# Start and save the app under 'controller'
runuser -l controller -c "pm2 start /home/controller/ecosystem.config.js && pm2 save"

log "PM2 configured. App should start now and on boot."

log "Disabling firstboot service"
systemctl disable firstboot.service || true
rm -f /etc/systemd/system/firstboot.service || true

log "First boot tasks complete"
