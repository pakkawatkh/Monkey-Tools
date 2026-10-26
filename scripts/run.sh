#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Kill ALL existing instances
pkill -9 -f "monkey-tools" || true
pkill -9 -f "monkey-copy" || true
pkill -9 -f "bxxs-clipboard" || true
pkill -9 -f "MacClipboard" || true
sleep 0.5

# Prefer /Applications/monkey-tools.app if it exists, otherwise local
if [ -d "/Applications/monkey-tools.app" ]; then
    open "/Applications/monkey-tools.app"
    echo "🚀 Launched /Applications/monkey-tools.app"
else
    open "${PROJECT_DIR}/monkey-tools.app"
    echo "🚀 Launched ${PROJECT_DIR}/monkey-tools.app"
fi

echo "👉 Press your shortcut (or Cmd + Shift + V) to open monkey-tools."
