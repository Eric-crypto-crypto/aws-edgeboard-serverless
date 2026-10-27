#!/usr/bin/env bash
# 容器创建后自动执行：把 ~/.aws 链接到持久化目录 /workspaces/.aws
set -euo pipefail

mkdir -p /workspaces/.aws

# 只有当 ~/.aws 还不是链接时才处理，避免重复执行出错
if [ ! -L "$HOME/.aws" ]; then
  rm -rf "$HOME/.aws"
  ln -s /workspaces/.aws "$HOME/.aws"
fi
