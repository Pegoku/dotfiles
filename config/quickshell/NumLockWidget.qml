import QtQuick
import Quickshell.Io

Rectangle {
    id: containerRect

    property int padding: 5
    property bool numLockOn: false

    anchors.verticalCenter: parent.verticalCenter
    radius: 9
    color: numLockOn ? "#2e5f3a" : "#353535"
    opacity: 0.9
    width: label.implicitWidth + padding * 2
    height: label.implicitHeight + padding * 2

    Text {
        id: label

        anchors.centerIn: parent
        text: "NUM"
        color: "#f2f2f2"
        font.pixelSize: 10
        font.bold: true
    }

    Process {
        id: numLockProc

        command: [
            "bash",
            "-lc",
            "while true; do " +
            "state=$(hyprctl devices -j 2>/dev/null | python3 -c 'import json,sys; s=sys.stdin.read();\ntry:\n d=json.loads(s)\nexcept Exception:\n print(\"OFF\"); raise SystemExit\nks=d.get(\"keyboards\",[])\nmain=next((k for k in ks if k.get(\"main\")), None)\nif main is None and ks: main=ks[0]\nprint(\"ON\" if (main and main.get(\"numLock\")) else \"OFF\")'); " +
            "echo \"NUM $state\"; " +
            "sleep 1; " +
            "done"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line.startsWith("NUM "))
                    return;

                containerRect.numLockOn = line.substring(4) === "ON";
            }
        }
    }
}
