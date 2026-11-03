#!/usr/bin/env bash
# Runs after the container is created: link ~/.aws to the persistent /workspaces/.aws
set -euo pipefail

mkdir -p /workspaces/.aws

# Only act when ~/.aws is not a symlink yet, so re-runs are safe
if [ ! -L "$HOME/.aws" ]; then
  rm -rf "$HOME/.aws"
  ln -s /workspaces/.aws "$HOME/.aws"
fi
