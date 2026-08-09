#!/usr/bin/env bash
set -euo pipefail

workspace=$(((($(hyprctl activeworkspace -j | jq -r .id) - 1) / 10) * 10 + $2))

case "$1" in
    workspace)
        dispatcher="hl.dsp.focus({ workspace = \"$workspace\" })"
        ;;
    movetoworkspace)
        dispatcher="hl.dsp.window.move({ workspace = \"$workspace\", follow = false })"
        ;;
    *)
        printf 'unsupported workspace action: %s\n' "$1" >&2
        exit 2
        ;;
esac

hyprctl dispatch "$dispatcher"
