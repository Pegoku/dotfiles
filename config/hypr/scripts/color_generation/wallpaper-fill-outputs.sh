#!/usr/bin/env bash
# Put the current wallpaper on outputs that don't have one.
#
# The wallpaper daemon caches per output name, so `restore` leaves a monitor it
# has never seen before on a flat colour. Copy whatever another output is
# showing onto the empty ones instead.

set -euo pipefail

XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

if command -v swww >/dev/null 2>&1; then
    client_bin="swww"
elif command -v awww >/dev/null 2>&1; then
    client_bin="awww"
else
    printf 'No supported wallpaper backend found. Install swww or awww.\n' >&2
    exit 1
fi

current_wallpaper() {
    local from_query
    from_query=$(printf '%s\n' "$1" | sed -n 's/.*currently displaying: image: //p' | head -n1)
    if [ -n "$from_query" ]; then
        printf '%s\n' "$from_query"
        return
    fi

    # Nothing on screen yet: fall back to the newest entry in the daemon cache,
    # whose last NUL-separated field is the image path.
    local newest
    newest=$(find "$XDG_CACHE_HOME"/swww "$XDG_CACHE_HOME"/awww -type f -printf '%T@ %p\n' 2>/dev/null |
        sort -rn | head -n1 | cut -d' ' -f2-)
    [ -n "$newest" ] && tr '\0' '\n' < "$newest" | tail -n1
}

# The daemon learns about a new output slightly after Hyprland does.
for _ in $(seq 10); do
    query=$("$client_bin" query 2>/dev/null) || exit 0

    empty=$(printf '%s\n' "$query" |
        sed -n 's/^:[[:space:]]*\([^:]*\):.*currently displaying: color: .*/\1/p' |
        paste -sd,)

    if [ -n "$empty" ]; then
        wallpaper=$(current_wallpaper "$query")
        if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
            "$client_bin" img "$wallpaper" --outputs "$empty" --transition-type none
        fi
        exit 0
    fi

    sleep 0.3
done
