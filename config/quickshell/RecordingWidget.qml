import QtQuick
import Quickshell.Io

Rectangle {
    id: containerRect

    property int padding: 5
    property bool recording: false
    property int startedAt: 0
    property int currentEpoch: Math.floor(Date.now() / 1000)

    function formatElapsed(totalSeconds) {
        var seconds = Math.max(0, totalSeconds);
        var hours = Math.floor(seconds / 3600);
        var minutes = Math.floor((seconds % 3600) / 60);
        var secs = seconds % 60;

        function pad(value) {
            return value < 10 ? "0" + value : "" + value;
        }

        if (hours > 0)
            return hours + ":" + pad(minutes) + ":" + pad(secs);

        return pad(minutes) + ":" + pad(secs);
    }

    anchors.verticalCenter: parent.verticalCenter
    radius: 9
    color: "#8f1d1d"
    opacity: recording ? 0.95 : 0
    visible: recording
    width: label.implicitWidth + padding * 2
    height: label.implicitHeight + padding * 2

    Text {
        id: label

        anchors.centerIn: parent
        text: containerRect.recording ? "REC " + containerRect.formatElapsed(containerRect.currentEpoch - containerRect.startedAt) : "REC"
        color: "#f7f0f0"
        font.pixelSize: 10
        font.bold: true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: containerRect.currentEpoch = Math.floor(Date.now() / 1000)
    }

    Process {
        id: recordingProc

        command: [
            "bash",
            "-lc",
            "while true; do " +
            "statefile=\"${XDG_RUNTIME_DIR:-/tmp}/record-script.active\"; " +
            "if [ -e \"$statefile\" ]; then " +
            "read -r started pid < \"$statefile\" 2>/dev/null || { echo 'REC OFF 0'; sleep 1; continue; }; " +
            "case $started in ''|*[!0-9]*) started=0 ;; esac; " +
            "case $pid in ''|*[!0-9]*) rm -f \"$statefile\"; echo 'REC OFF 0'; sleep 1; continue ;; esac; " +
            "exe=$(readlink \"/proc/$pid/exe\" 2>/dev/null || true); " +
            "if [ \"${exe##*/}\" = gpu-screen-recorder ]; then " +
            "echo \"REC ON $started\"; " +
            "else rm -f \"$statefile\"; echo 'REC OFF 0'; fi; " +
            "else echo 'REC OFF 0'; fi; " +
            "sleep 1; " +
            "done"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line.startsWith("REC "))
                    return;

                var parts = line.split(" ");
                containerRect.recording = parts.length >= 2 && parts[1] === "ON";
                containerRect.startedAt = parts.length >= 3 ? parseInt(parts[2], 10) || 0 : 0;
            }
        }
    }
}
