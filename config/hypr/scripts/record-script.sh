#!/usr/bin/env bash

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}
getaudiooutput() {
    pactl list sources | grep 'Name' | grep 'monitor' | cut -d ' ' -f2
}
getactivemonitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}

statefile="${XDG_RUNTIME_DIR:-/tmp}/record-script.active"

start_recording() {
    date +%s > "$statefile"

    (
        trap 'rm -f "$statefile"' EXIT
        "$@"
    ) & disown
}

mkdir -p "$(xdg-user-dir VIDEOS)"
cd "$(xdg-user-dir VIDEOS)" || exit
if pgrep wf-recorder > /dev/null; then
    notify-send "Recording Stopped" "Stopped" -a 'record-script.sh' &
    rm -f "$statefile"
    pkill wf-recorder &
else
    notify-send "Starting recording" 'recording_'"$(getdate)"'.mkv' -a 'record-script.sh'
    if [[ "$1" == "--sound" ]]; then
        geometry="$(slurp)" || exit
        start_recording wf-recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mkv' -t --geometry "$geometry" --audio="$(getaudiooutput)"
    elif [[ "$1" == "--fullscreen-sound" ]]; then
        start_recording wf-recorder -o "$(getactivemonitor)" --pixel-format yuv420p -f './recording_'"$(getdate)"'.mkv' -t --audio="$(getaudiooutput)"
    elif [[ "$1" == "--fullscreen" ]]; then
        start_recording wf-recorder -o "$(getactivemonitor)" --pixel-format yuv420p -f './recording_'"$(getdate)"'.mkv' -t
    else
        geometry="$(slurp)" || exit
        start_recording wf-recorder --pixel-format yuv420p -f './recording_'"$(getdate)"'.mkv' -t --geometry "$geometry"
    fi
fi
