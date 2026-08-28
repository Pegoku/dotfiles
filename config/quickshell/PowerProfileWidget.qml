import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: containerRect

    property string profile: "balanced"
    property bool profileAvailable: true
    readonly property string iconBase: "file:///usr/share/icons/Adwaita/symbolic/status/"
    readonly property string nextProfile: profile === "performance" ? "balanced" : profile === "balanced" ? "power-saver" : "performance"

    function displayName(value) {
        if (value === "performance")
            return "Performance";
        if (value === "power-saver")
            return "Battery saver";
        return "Balanced";
    }

    function setProfile(value) {
        profile = value;
        Quickshell.execDetached(["powerprofilesctl", "set", value]);
    }

    anchors.verticalCenter: parent.verticalCenter
    radius: 9
    color: profile === "performance" ? "#7a3131" : profile === "power-saver" ? "#315d45" : "#315675"
    opacity: profileAvailable ? 0.95 : 0.45
    width: 24
    height: 24

    Image {
        id: icon

        anchors.centerIn: parent
        width: 14
        height: 14
        source: containerRect.iconBase + "power-profile-" + containerRect.profile + "-symbolic.svg"
        smooth: true
        layer.enabled: true

        layer.effect: ColorOverlay {
            color: "#f2f2f2"
        }
    }

    ToolTip.visible: hoverArea.containsMouse
    ToolTip.text: profileAvailable
        ? "Power mode: " + displayName(profile) + "\nClick for " + displayName(nextProfile)
        : "Power profiles are unavailable"
    ToolTip.delay: 150
    ToolTip.timeout: 0

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        enabled: containerRect.profileAvailable
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor

        onClicked: containerRect.setProfile(containerRect.nextProfile)
    }

    Process {
        command: [
            "bash",
            "-lc",
            "while true; do powerprofilesctl get 2>/dev/null || echo unavailable; sleep 2; done"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var value = data.trim();
                if (value === "performance" || value === "balanced" || value === "power-saver") {
                    containerRect.profile = value;
                    containerRect.profileAvailable = true;
                } else if (value === "unavailable") {
                    containerRect.profileAvailable = false;
                }
            }
        }
    }
}
