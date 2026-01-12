#!/usr/bin/env bash

win=$(hyprctl activewindow -j | jq -r '.address')
cur=$(hyprctl clients -j | jq -r ".[] | select(.address==\"$win\") | .opacity")

if (( $(echo "$cur < 0.99" | bc -l) )); then
  hyprctl dispatch setprop address:$win opacity 1.0
  echo 1
else
  hyprctl dispatch setprop address:$win opacity 0.95
  echo 95
fi

