#!/bin/bash
# Deploy from the VPS checkout: ./deploy.sh
# Kamal reads .kamal/secrets itself, and deploy.yml passes GIT_REVISION to the
# build, so all this does is put rbenv on PATH, pull, and deploy.

set -euo pipefail
cd "$(dirname "$0")"

export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"

if [ ! -f .kamal/secrets ]; then
  echo "Error: .kamal/secrets not found" >&2
  exit 1
fi

git pull --ff-only
echo "Deploying $(git rev-parse --short HEAD)..."
bundle exec kamal deploy
echo "Deploy complete."
