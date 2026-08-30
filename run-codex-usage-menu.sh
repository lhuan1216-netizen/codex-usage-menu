#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
swiftc CodexUsageMenu.swift -o CodexUsageMenu -framework AppKit

if pgrep -f "$(pwd)/CodexUsageMenu" >/dev/null 2>&1; then
  echo "CodexUsageMenu is already running."
  exit 0
fi

nohup ./CodexUsageMenu >/tmp/CodexUsageMenu.log 2>&1 &
disown
echo "CodexUsageMenu started in the background."
