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

is_wf_recorder_pid() {
    local pid="$1"

    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    [[ -r "/proc/$pid/comm" ]] || return 1
    [[ "$(<"/proc/$pid/comm")" == "wf-recorder" ]]
}

has_active_recording() {
    local recorder_pid

    if [[ -r "$statefile" ]]; then
        read -r _ recorder_pid < "$statefile" || recorder_pid=""
    else
        recorder_pid=""
    fi

    is_wf_recorder_pid "$recorder_pid" || pgrep -u "$UID" -x wf-recorder > /dev/null
}

start_recording() {
    local started tmpfile

    started="$(date +%s)"
    tmpfile="$(mktemp "${statefile}.XXXXXX")" || return 1

    (
        trap 'rm -f "$statefile" "$tmpfile"' EXIT

        "$@" &
        recorder_pid=$!
        printf '%s %s\n' "$started" "$recorder_pid" > "$tmpfile" && mv "$tmpfile" "$statefile"
        wait "$recorder_pid"
    ) & disown
}

mkdir -p "$(xdg-user-dir VIDEOS)"
cd "$(xdg-user-dir VIDEOS)" || exit
if has_active_recording; then
    notify-send "Recording Stopped" "Stopped" -a 'record-script.sh' &
    if [[ -r "$statefile" ]]; then
        read -r _ recorder_pid < "$statefile" || recorder_pid=""
    else
        recorder_pid=""
    fi

    if is_wf_recorder_pid "$recorder_pid"; then
        kill "$recorder_pid" 2>/dev/null || true
    else
        pkill -u "$UID" -x wf-recorder 2>/dev/null || true
    fi
    rm -f "$statefile"
else
    rm -f "$statefile"
    notify-send "Starting recording" 'recording_'"$(getdate)"'.mkv' -a 'record-script.sh'
    render_device="$(getrenderdevice)"
    recorder_args=(--codec hevc_vaapi --device "$render_device" --framerate 60 --bframes 0 -p rc_mode=CQP -p qp=32 -f './recording_'"$(getdate)"'.mkv')

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
