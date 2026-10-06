#!/usr/bin/env bash
set -euo pipefail
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
exec lua "$config_home/hypr/scripts/hyprland/keybinds-help.lua" \
    "$config_home/hypr/hyprland/keybinds.lua"
