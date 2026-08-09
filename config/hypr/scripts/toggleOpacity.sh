#!/usr/bin/env bash

win=$(hyprctl activewindow -j | jq -r '.address')
cur=$(hyprctl clients -j | jq -r ".[] | select(.address==\"$win\") | .opacity")

if (( $(echo "$cur < 0.99" | bc -l) )); then
  hyprctl dispatch "hl.dsp.window.set_prop({ window = \"address:$win\", prop = \"opacity\", value = \"1.0\" })"
  echo 1
else
  hyprctl dispatch "hl.dsp.window.set_prop({ window = \"address:$win\", prop = \"opacity\", value = \"0.95\" })"
  echo 95
fi
