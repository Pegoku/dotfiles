#!/usr/bin/env bash

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}
getaudiooutput() {
    local sink

    sink="$(pactl get-default-sink 2>/dev/null)" && [[ -n "$sink" ]] && {
        printf '%s.monitor\n' "$sink"
        return
    }

    pactl list sources | grep 'Name' | grep 'monitor' | cut -d ' ' -f2 | head -n 1
}
getactivemonitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}
getregion() {
    local selection position size x y

    selection="$(slurp)" || return 1
    read -r position size <<< "$selection"
    x="${position%,*}"
    y="${position#*,}"
    printf '%s+%s+%s\n' "$size" "$x" "$y"
}

statefile="${XDG_RUNTIME_DIR:-/tmp}/record-script.active"

is_recorder_pid() {
    local pid="$1"
    local exe

    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    exe="$(readlink "/proc/$pid/exe" 2>/dev/null)" || return 1
    [[ "${exe##*/}" == "gpu-screen-recorder" ]]
}

has_active_recording() {
    local recorder_pid

    if [[ -r "$statefile" ]]; then
        read -r _ recorder_pid < "$statefile" || recorder_pid=""
    else
        recorder_pid=""
    fi

    is_recorder_pid "$recorder_pid" || pgrep -u "$UID" -f 'gpu-screen-recorder' > /dev/null
}

stop_recording_pid() {
    local pid="$1"

    is_recorder_pid "$pid" || return 1
    kill -INT "$pid" 2>/dev/null || return 1

    for _ in {1..20}; do
        is_recorder_pid "$pid" || return 0
        sleep 0.5
    done

    notify-send "Stopping recording" "gpu-screen-recorder ignored SIGINT; sending SIGTERM." -a 'record-script.sh' &
    kill -TERM "$pid" 2>/dev/null || return 1

    for _ in {1..20}; do
        is_recorder_pid "$pid" || return 0
        sleep 0.5
    done

    notify-send "Force stopping recording" "gpu-screen-recorder ignored SIGINT and SIGTERM." -a 'record-script.sh' &
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

    if is_recorder_pid "$recorder_pid"; then
        stop_recording_pid "$recorder_pid" || exit
    else
        while read -r recorder_pid; do
            stop_recording_pid "$recorder_pid" || exit
        done < <(pgrep -u "$UID" -f 'gpu-screen-recorder')
    fi
    rm -f "$statefile"
    notify-send "Recording Saved" "Stopped" -a 'record-script.sh' &
else
    rm -f "$statefile"
    output_file='./recording_'"$(getdate)"'.mkv'
    notify-send "Starting recording" "$output_file" -a 'record-script.sh'
    recorder_args=(-c mkv -f 60 -k h264 -q high -o "$output_file")

    if [[ "$1" == "--sound" ]]; then
        geometry="$(getregion)" || exit
        start_recording gpu-screen-recorder -w region -region "$geometry" "${recorder_args[@]}" -a "$(getaudiooutput)"
    elif [[ "$1" == "--fullscreen-sound" ]]; then
        start_recording gpu-screen-recorder -w "$(getactivemonitor)" "${recorder_args[@]}" -a "$(getaudiooutput)"
    elif [[ "$1" == "--fullscreen" ]]; then
        start_recording gpu-screen-recorder -w "$(getactivemonitor)" "${recorder_args[@]}"
    else
        geometry="$(getregion)" || exit
        start_recording gpu-screen-recorder -w region -region "$geometry" "${recorder_args[@]}"
    fi
fi
