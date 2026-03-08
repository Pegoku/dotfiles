import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: containerRect

    property int padding: 5
    property bool caffeineOn: false

    function applyState(enabled) {
        caffeineOn = enabled;
        var flag = enabled ? "1" : "0";
        var cmd = "mkdir -p \"$HOME/.local/state/hypr\" && printf %s " + flag + " > \"$HOME/.local/state/hypr/caffeine_enabled\"";
        Quickshell.execDetached(["bash", "-lc", cmd]);
    }

    anchors.verticalCenter: parent.verticalCenter
    radius: 9
    color: caffeineOn ? "#6a4b1f" : "#353535"
    opacity: 0.9
    width: mug.implicitWidth + padding * 2
    height: mug.implicitHeight + padding * 2

    Text {
        id: mug

        anchors.centerIn: parent
        text: "☕"
        color: "#f2f2f2"
        font.pixelSize: 12
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        onClicked: {
            containerRect.applyState(!containerRect.caffeineOn);
        }
    }

    Process {
        id: initialStateProc

        command: [
            "bash",
            "-lc",
            "if [ -f \"$HOME/.local/state/hypr/caffeine_enabled\" ] && [ \"$(cat \"$HOME/.local/state/hypr/caffeine_enabled\")\" = \"1\" ]; then echo ON; else echo OFF; fi"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var value = data.trim();
                containerRect.caffeineOn = value === "ON";
            }
        }
    }
}
