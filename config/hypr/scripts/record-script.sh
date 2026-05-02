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
getrenderdevice() {
    for render in /sys/class/drm/renderD*; do
        [[ -e "$render/device/class" ]] || continue

        # On this laptop the integrated GPU shows up as a display controller,
        # and matching the compositor's GPU avoids VAAPI hwupload failures.
        if [[ "$(<"$render/device/class")" == "0x038000" ]]; then
            printf '/dev/dri/%s\n' "${render##*/}"
            return
        fi
    done

    ls /dev/dri/renderD* 2>/dev/null | head -n 1
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
    render_device="$(getrenderdevice)"
    recorder_args=(--codec h264_vaapi --device "$render_device" -f './recording_'"$(getdate)"'.mkv')

    if [[ "$1" == "--sound" ]]; then
        geometry="$(slurp)" || exit
        start_recording wf-recorder "${recorder_args[@]}" --geometry "$geometry" --audio="$(getaudiooutput)"
    elif [[ "$1" == "--fullscreen-sound" ]]; then
        start_recording wf-recorder -o "$(getactivemonitor)" "${recorder_args[@]}" --audio="$(getaudiooutput)"
    elif [[ "$1" == "--fullscreen" ]]; then
        start_recording wf-recorder -o "$(getactivemonitor)" "${recorder_args[@]}"
    else
        geometry="$(slurp)" || exit
        start_recording wf-recorder "${recorder_args[@]}" --geometry "$geometry"
    fi
fi
