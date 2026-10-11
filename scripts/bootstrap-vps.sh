#!/usr/bin/env bash
# Idempotent VPS bootstrap for Kamal. Run: bootstrap-vps.sh <user>@<tailnet-host>
# Installs Docker if missing; kamal-proxy is started by `kamal setup` itself.
# Works as a non-root user with sudo (root SSH is disabled on the VPS).
set -euo pipefail
target=${1:?usage: bootstrap-vps.sh user@host}

ssh -o StrictHostKeyChecking=accept-new "$target" 'bash -s' <<'EOF'
set -euo pipefail
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | $SUDO sh
  $SUDO usermod -aG docker "$USER"
fi
$SUDO systemctl enable --now docker
if command -v ufw >/dev/null 2>&1 && $SUDO ufw status | grep -q "Status: active"; then
  $SUDO ufw allow 80/tcp >/dev/null
  $SUDO ufw allow 443/tcp >/dev/null
fi
docker --version
echo BOOTSTRAP_OK
EOF
