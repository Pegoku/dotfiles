#!/usr/bin/env bash

set -euo pipefail

enabled_zoom="${1:-2}"

current_zoom="$({ hyprctl getoption cursor.zoom_factor -j 2>/dev/null || printf '{"float":1}'; } | jq -r '.float // 1')"

if awk "BEGIN { exit !(${current_zoom} > 1.01) }"; then
    hyprctl eval 'hl.gesture({ fingers = 2, direction = "pinchin", action = "unset", zoom_level = 1.15, mode = "mult" })' >/dev/null
    hyprctl eval 'hl.gesture({ fingers = 2, direction = "pinchout", action = "unset", zoom_level = 0.869565, mode = "mult" })' >/dev/null
    hyprctl eval 'hl.config({ cursor = { zoom_factor = 1 } })' >/dev/null
    exit 0
fi

hyprctl eval "hl.config({ cursor = { zoom_factor = ${enabled_zoom} } })" >/dev/null
hyprctl eval 'hl.gesture({ fingers = 2, direction = "pinchin", action = "cursorZoom", zoom_level = 1.15, mode = "mult" })' >/dev/null
hyprctl eval 'hl.gesture({ fingers = 2, direction = "pinchout", action = "cursorZoom", zoom_level = 0.869565, mode = "mult" })' >/dev/null
