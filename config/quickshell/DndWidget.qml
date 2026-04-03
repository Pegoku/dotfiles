import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: containerRect

    property bool dndOn: false
    property string enabledIcon: "file:///usr/share/icons/Adwaita/symbolic/legacy/preferences-system-notifications-symbolic.svg"
    property string disabledIcon: "file:///usr/share/icons/Adwaita/symbolic/status/notifications-disabled-symbolic.svg"

    function applyState(enabled) {
        dndOn = enabled;
        Quickshell.execDetached(["makoctl", "mode", enabled ? "-a" : "-r", "do-not-disturb"]);
    }

    anchors.verticalCenter: parent.verticalCenter
    radius: 9
    color: dndOn ? "#5b2344" : "#353535"
    opacity: 0.9
    width: 24
    height: 24

    Image {
        id: icon

        anchors.centerIn: parent
        width: 14
        height: 14
        source: containerRect.dndOn ? containerRect.disabledIcon : containerRect.enabledIcon
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
            containerRect.applyState(!containerRect.dndOn);
        }
    }

    Process {
        id: initialStateProc

        command: [
            "bash",
            "-lc",
            "if makoctl mode | grep -qx 'do-not-disturb'; then echo ON; else echo OFF; fi"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                containerRect.dndOn = data.trim() === "ON";
            }
        }
    }
}
