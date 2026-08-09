#!/usr/bin/env bash
set -euo pipefail

workspace_name="gromit"
workspace_full="special:${workspace_name}"

is_visible() {
    hyprctl monitors -j | jq -e --arg ws "$workspace_full" 'any(.[]; .specialWorkspace.name == $ws)' >/dev/null
}

ensure_running() {
    if ! pgrep -x gromit-mpx >/dev/null; then
        hyprctl dispatch "hl.dsp.exec_cmd(\"gromit-mpx\", { workspace = \"${workspace_full} silent\" })"
        sleep 0.5
    fi
}

show_workspace() {
    if ! is_visible; then
        hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$workspace_name\")"
        sleep 0.1
    fi
}

case "${1:-toggle-workspace}" in
    toggle-workspace)
        ensure_running
        hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$workspace_name\")"
        ;;
    paint)
        ensure_running
        show_workspace
        gromit-mpx --toggle
        ;;
    clear)
        if pgrep -x gromit-mpx >/dev/null; then
            gromit-mpx --clear
        fi
        ;;
    quit)
        if pgrep -x gromit-mpx >/dev/null; then
            gromit-mpx --quit
        fi
        ;;
esac
