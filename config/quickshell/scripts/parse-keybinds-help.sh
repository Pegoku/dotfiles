#!/usr/bin/env bash

set -euo pipefail

awk '
function trim(s) {
    sub(/^[ 	]+/, "", s)
    sub(/[ 	]+$/, "", s)
    return s
}

function normalize_mods(s) {
    s = trim(s)
    gsub(/[[:space:]]*\+[[:space:]]*/, "+", s)
    gsub(/[[:space:]]+/, "+", s)
    gsub(/\+\+/, "+", s)
    return s
}

function ensure_section(title) {
    if (!(title in seen)) {
        seen[title] = 1
        order[++order_count] = title
    }
}

BEGIN {
    current_section = "General"
    ensure_section(current_section)
}

{
    raw = $0
    sub(/\r$/, "", raw)

    if (raw ~ /^[ 	]*##!/) {
        current_section = raw
        sub(/^[ 	]*##![ 	]*/, "", current_section)
        current_section = trim(current_section)
        if (current_section != "")
            ensure_section(current_section)
        next
    }

    if (raw !~ /^[ 	]*bind[a-z]*[ 	]*=/)
        next
    if (raw ~ /#[ 	]*\[hidden\][ 	]*$/)
        next

    line = raw
    desc = ""
    hash_pos = index(line, "#")
    if (hash_pos > 0) {
        desc = trim(substr(line, hash_pos + 1))
        line = substr(line, 1, hash_pos - 1)
    }

    if (desc ~ /^\[hidden\]([[:space:]]|$)/)
        next

    sub(/^[ 	]*bind[a-z]*[ 	]*=[ 	]*/, "", line)
    count = split(line, parts, ",")

    mods = count >= 1 ? trim(parts[1]) : ""
    key = count >= 2 ? trim(parts[2]) : ""
    dispatcher = count >= 3 ? trim(parts[3]) : ""
    args = ""

    if (count >= 4) {
        args = parts[4]
        for (i = 5; i <= count; ++i)
            args = args "," parts[i]
        args = trim(args)
    }

    mods = normalize_mods(mods)
    shortcut = key
    if (mods != "" && key != "")
        shortcut = mods " + " key
    else if (mods != "")
        shortcut = mods

    action = dispatcher
    if (args != "")
        action = action " " args
    if (desc == "")
        desc = action

    if (shortcut != "")
        print "ENTRY\t" current_section "\t" shortcut "\t" desc "\t" action
}

END {
    for (i = 1; i <= order_count; ++i)
        print "SECTION\t" order[i]
}
' "$HOME/.config/hypr/hyprland/keybinds.conf"
