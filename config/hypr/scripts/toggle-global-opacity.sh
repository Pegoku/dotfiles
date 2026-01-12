#!/bin/bash

# File to track global opacity state
STATE_FILE="/tmp/hypr_global_opacity"

if [ -f "$STATE_FILE" ]; then
    # Global opacity is currently ON, turn it OFF
    rm "$STATE_FILE"
    # Get all window addresses and remove the tag
    hyprctl clients -j | jq -r '.[] | .address' | while read addr; do
        hyprctl dispatch tagwindow -- -global_opaque "address:$addr"
    done
    notify-send "Global opacity" "OFF" -t 1000
else
    # Global opacity is currently OFF, turn it ON
    touch "$STATE_FILE"
    # Get all window addresses and add the tag
    hyprctl clients -j | jq -r '.[] | .address' | while read addr; do
        hyprctl dispatch tagwindow +global_opaque "address:$addr"
    done
    notify-send "Global opacity" "ON" -t 1000
fi

