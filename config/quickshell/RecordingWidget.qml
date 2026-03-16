import QtQuick
import Quickshell.Io

Rectangle {
    id: containerRect

    property int padding: 5
    property bool recording: false
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
        text: "REC"
        color: "#f7f0f0"
        font.pixelSize: 10
        font.bold: true
    }

    Process {
        id: recordingProc

        command: [
            "bash",
            "-lc",
            "while true; do " +
            "statefile=\"${XDG_RUNTIME_DIR:-/tmp}/record-script.active\"; " +
            "if [ -e \"$statefile\" ]; then echo 'REC ON'; else echo 'REC OFF'; fi; " +
            "sleep 1; " +
            "done"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line.startsWith("REC "))
                    return;

                containerRect.recording = line.substring(4) === "ON";
            }
        }
    }
}
