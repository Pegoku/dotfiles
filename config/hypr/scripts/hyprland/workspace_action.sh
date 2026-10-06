#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 || ! "$2" =~ ^([1-9]|10)$ ]]; then
    printf 'usage: %s workspace|movetoworkspace 1..10\n' "$0" >&2
    exit 2
fi

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

# The same script is referenced by legacy .conf bindings and may also be used
# with Lua. Detect the running manager, not merely the presence of a Lua file.
probe=$(hyprctl eval 'return true' 2>&1) || {
    if [[ "$probe" != *'only supported with the lua config manager'* ]]; then
        printf '%s\n' "$probe" >&2
        exit 1
    fi
}
if [[ "$probe" == *'only supported with the lua config manager'* ]]; then
    if [[ "$1" == workspace ]]; then
        hyprctl dispatch workspace "$workspace"
    else
        hyprctl dispatch movetoworkspacesilent "$workspace"
    fi
else
    hyprctl dispatch "$dispatcher"
fi
