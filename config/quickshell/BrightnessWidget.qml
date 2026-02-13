import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: containerRect

    property int padding: 6
    property real brightness: 0
    property bool available: true
    property int brightnessStepPercent: 5
    property color fgColor: "#f2f2f2"
    property color bgColor: "#1c1c1c"
    property color barBg: "#3a3a3a"
    property string iconBase: "file:///usr/share/icons/Adwaita/symbolic/status/"
    property string iconName: "display-brightness-symbolic"

    property string tooltipText: {
        if (!available)
            return "Brightness unavailable";
        var pct = Math.round(brightness * 100);
        if (pct < 0)
            pct = 0;
        return "Brightness · " + pct + "%";
    }

    function stepUp() {
        Quickshell.execDetached(["brightnessctl", "set", brightnessStepPercent + "%+"]);
    }

    function stepDown() {
        Quickshell.execDetached(["brightnessctl", "set", brightnessStepPercent + "%-"]);
    }

    anchors.verticalCenter: parent.verticalCenter
    radius: 12
    color: bgColor
    opacity: 0.85
    layer.enabled: true
    width: contentRow.implicitWidth + padding * 2
    height: contentRow.implicitHeight + padding * 2

    ToolTip.visible: hoverArea.containsMouse && containerRect.tooltipText.length > 0
    ToolTip.text: containerRect.tooltipText
    ToolTip.delay: 150
    ToolTip.timeout: 0

    Process {
        id: brightnessProc

        command: [
            "bash",
            "-lc",
            "while true; do " +
            "val=$(brightnessctl -m 2>/dev/null | awk -F',' '{gsub(/%/,\"\",$5); print $5}'); " +
            "if [ -z \"$val\" ]; then echo 'BRT NA'; else echo \"BRT $val\"; fi; " +
            "sleep 1; done"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line)
                    return;
                if (!line.startsWith("BRT "))
                    return;

                var parts = line.split(/\s+/);
                if (parts.length < 2)
                    return;

                if (parts[1] === "NA") {
                    containerRect.available = false;
                    containerRect.brightness = 0;
                    return;
                }

                containerRect.available = true;
                var pct = Number(parts[1]);
                if (!isNaN(pct))
                    containerRect.brightness = Math.max(0, Math.min(1, pct / 100));
            }
        }
    }

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 6

        Image {
            id: brightnessIcon

            width: 16
            height: 16
            source: containerRect.iconBase + containerRect.iconName + ".svg"
            smooth: true
            layer.enabled: true

            layer.effect: ColorOverlay {
                color: containerRect.fgColor
            }
        }

        Text {
            id: brightnessText

            text: containerRect.available ? (Math.round(containerRect.brightness * 100) + "%") : "N/A"
            color: containerRect.fgColor
            font.bold: true
        }

        Rectangle {
            id: brightnessBar

            width: 48
            height: 4
            radius: 2
            color: containerRect.barBg
            opacity: containerRect.available ? 1 : 0.5

            Rectangle {
                id: brightnessFill

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: Math.max(2, parent.width * Math.max(0, Math.min(1, containerRect.brightness)))
                radius: 2
                color: containerRect.fgColor

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onWheel: {
            if (!containerRect.available)
                return;
            if (wheel.angleDelta.y > 0)
                containerRect.stepUp();
            else if (wheel.angleDelta.y < 0)
                containerRect.stepDown();
        }
    }
}
