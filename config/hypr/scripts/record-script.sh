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

stop_recording_pid() {
    local pid="$1"

    is_wf_recorder_pid "$pid" || return 1
    kill -INT "$pid" 2>/dev/null || return 1

    for _ in {1..20}; do
        is_wf_recorder_pid "$pid" || return 0
        sleep 0.5
    done

    notify-send "Stopping recording" "wf-recorder ignored SIGINT; sending SIGTERM." -a 'record-script.sh' &
    kill -TERM "$pid" 2>/dev/null || return 1

    for _ in {1..20}; do
        is_wf_recorder_pid "$pid" || return 0
        sleep 0.5
    done

    notify-send "Force stopping recording" "wf-recorder ignored SIGINT and SIGTERM." -a 'record-script.sh' &
    kill -KILL "$pid" 2>/dev/null || return 1
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
    notify-send "Stopping recording" "Finalizing file..." -a 'record-script.sh' &
    if [[ -r "$statefile" ]]; then
        read -r _ recorder_pid < "$statefile" || recorder_pid=""
    else
        recorder_pid=""
    fi

    if is_wf_recorder_pid "$recorder_pid"; then
        stop_recording_pid "$recorder_pid" || exit
    else
        while read -r recorder_pid; do
            stop_recording_pid "$recorder_pid" || exit
        done < <(pgrep -u "$UID" -x wf-recorder)
    fi
    rm -f "$statefile"
    notify-send "Recording Saved" "Stopped" -a 'record-script.sh' &
else
    rm -f "$statefile"
    notify-send "Starting recording" 'recording_'"$(getdate)"'.mkv' -a 'record-script.sh'
    render_device="$(getrenderdevice)"
    recorder_args=(--codec h264_vaapi --device "$render_device" --framerate 60 --no-damage --bframes 0 -f './recording_'"$(getdate)"'.mkv')

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
