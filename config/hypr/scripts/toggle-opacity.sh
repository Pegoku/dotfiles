#!/bin/bash

# Get the active window's address
ADDR=$(hyprctl activewindow | head -1 | awk '{print $2}')

if [ -z "$ADDR" ]; then
    notify-send "Error" "Could not get active window"
    exit 1
fi

# Try using hyprctl to toggle the opaque property directly on the window
hyprctl dispatch exec "hyprctl keyword windowrule 'opaque 0' 'address:$ADDR'"
