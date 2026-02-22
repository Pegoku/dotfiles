pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var entries: []
    property var scanBuffer: []
    property int playingCount: entries.length
    property bool playerctlAvailable: true

    readonly property var primary: entries.length > 0 ? entries[0] : null
    readonly property string primaryTitle: primary ? primary.title : "No media"
    readonly property string primaryArtist: primary ? primary.artist : ""

    Process {
        id: nowPlayingProc

        command: [
            "bash",
            "-lc",
            "while true; do " +
            "echo 'NP_BEGIN'; " +
            "if ! command -v playerctl >/dev/null 2>&1; then " +
            "echo 'NP_PLAYERCTL_MISSING'; " +
            "echo 'NP_END'; " +
            "sleep 2; " +
            "continue; " +
            "fi; " +
            "playerctl -a metadata --format '{{status}}\t{{playerName}}\t{{xesam:title}}\t{{xesam:artist}}\t{{mpris:artUrl}}\t{{duration(position)}}\t{{duration(mpris:length)}}' 2>/dev/null | " +
            "awk -F'\t' '$1==\"Playing\" {" +
            "player=$2; title=$3; artist=$4; art=$5; pos=$6; len=$7; " +
            "if (title==\"\") title=\"Unknown title\"; " +
            "if (artist==\"\") artist=\"Unknown artist\"; " +
            "gsub(/[\r\n\t]/, \" \", player); " +
            "gsub(/[\r\n\t]/, \" \", title); " +
            "gsub(/[\r\n\t]/, \" \", artist); " +
            "gsub(/[\r\n\t]/, \" \", art); " +
            "gsub(/[\r\n\t]/, \" \", pos); " +
            "gsub(/[\r\n\t]/, \" \", len); " +
            "print \"NP_ITEM\t\" player \"\t\" title \"\t\" artist \"\t\" art \"\t\" pos \"\t\" len" +
            "}'; " +
            "echo 'NP_END'; " +
            "sleep 2; " +
            "done"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line)
                    return;

                if (line === "NP_BEGIN") {
                    root.scanBuffer = [];
                    root.playerctlAvailable = true;
                    return;
                }

                if (line === "NP_PLAYERCTL_MISSING") {
                    root.playerctlAvailable = false;
                    return;
                }

                if (line === "NP_END") {
                    root.entries = root.scanBuffer;
                    return;
                }

                if (!line.startsWith("NP_ITEM\t"))
                    return;

                var parts = line.split("\t");
                if (parts.length < 7)
                    return;

                root.scanBuffer.push({
                    player: parts[1],
                    title: parts[2],
                    artist: parts[3],
                    artUrl: parts[4],
                    position: parts[5],
                    length: parts[6]
                });
            }
        }
    }
}
