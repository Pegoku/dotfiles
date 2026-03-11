import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: containerRect

    property int padding: 5
    property bool caffeineOn: false
    property string iconBase: "file:///usr/share/icons/Adwaita/symbolic/status/"

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
    width: 24
    height: 24

    Image {
        id: icon

        anchors.centerIn: parent
        width: 14
        height: 14
        source: containerRect.iconBase + (containerRect.caffeineOn ? "night-light-disabled-symbolic.svg" : "night-light-symbolic.svg")
        smooth: true
        layer.enabled: true

        layer.effect: ColorOverlay {
            color: "#f2f2f2"
        }
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
