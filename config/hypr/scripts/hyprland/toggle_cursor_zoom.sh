#!/usr/bin/env bash

set -euo pipefail

enabled_zoom="${1:-2}"

pinch_in_args="2, pinchin, cursorZoom, 0.833333, mult"
pinch_out_args="2, pinchout, cursorZoom, 1.2, mult"

current_zoom="$({ hyprctl getoption cursor:zoom_factor -j 2>/dev/null || printf '{"float":1}'; } | jq -r '.float // 1')"

if awk "BEGIN { exit !(${current_zoom} > 1.01) }"; then
    hyprctl keyword gesture "2, pinchin, unset" >/dev/null
    hyprctl keyword gesture "2, pinchout, unset" >/dev/null
    hyprctl keyword cursor:zoom_factor 1 >/dev/null
    exit 0
fi

hyprctl keyword cursor:zoom_factor "${enabled_zoom}" >/dev/null
hyprctl keyword gesture "${pinch_in_args}" >/dev/null
hyprctl keyword gesture "${pinch_out_args}" >/dev/null
