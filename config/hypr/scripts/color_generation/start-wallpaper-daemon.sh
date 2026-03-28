#!/usr/bin/env bash

set -euo pipefail

XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

if command -v swww-daemon >/dev/null 2>&1 && command -v swww >/dev/null 2>&1; then
    daemon_bin="swww-daemon"
    client_bin="swww"
elif command -v awww-daemon >/dev/null 2>&1 && command -v awww >/dev/null 2>&1; then
    daemon_bin="awww-daemon"
    client_bin="awww"
    mkdir -p "$XDG_CACHE_HOME/awww"
else
    printf 'No supported wallpaper backend found. Install swww or awww.\n' >&2
    exit 1
fi

if ! pgrep -x "$daemon_bin" >/dev/null 2>&1; then
    "$daemon_bin" --format argb &
fi

sleep 1
"$client_bin" restore >/dev/null 2>&1 || true
