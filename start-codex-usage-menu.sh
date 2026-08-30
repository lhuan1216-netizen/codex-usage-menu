#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if pgrep -f "$(pwd)/CodexUsageMenu" >/dev/null 2>&1; then
  exit 0
fi

./CodexUsageMenu >/tmp/CodexUsageMenu.log 2>&1
