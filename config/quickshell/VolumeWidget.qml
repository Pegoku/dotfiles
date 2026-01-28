import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: containerRect

    property int padding: 6
    property real volume: 0
    property bool muted: false
    property bool available: true
    property int volumeStepPercent: 5
    property color fgColor: "#f2f2f2"
    property color bgColor: "#1c1c1c"
    property color barBg: "#3a3a3a"
    property string iconBase: "file:///usr/share/icons/Adwaita/symbolic/status/"

    property string tooltipText: {
        if (!available)
            return "Volume unavailable";
        var pct = Math.round(volume * 100);
        if (pct < 0)
            pct = 0;
        var state = muted || pct === 0 ? "Muted" : "Volume";
        return state + " · " + pct + "%";
    }

    function volumeIconName() {
        if (!available)
            return "audio-volume-muted-symbolic";
        if (muted || volume <= 0.01)
            return "audio-volume-muted-symbolic";
        if (volume > 1.0)
            return "audio-volume-overamplified-symbolic";
        if (volume < 0.33)
            return "audio-volume-low-symbolic";
        if (volume < 0.66)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    function stepUp() {
        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", volumeStepPercent + "%+"]);
    }

    function stepDown() {
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volumeStepPercent + "%-"]);
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
        id: volumeProc

        command: [
            "bash",
            "-lc",
            "while true; do " +
            "line=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
            "if [ -z \"$line\" ]; then echo 'VOL NA'; else " +
            "val=$(echo \"$line\" | awk '{print $2}'); " +
            "muted=$(echo \"$line\" | grep -q MUTED && echo 1 || echo 0); " +
            "echo \"VOL $val $muted\"; fi; " +
            "sleep 0.8; done"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line)
                    return;
                if (!line.startsWith("VOL "))
                    return;

                var parts = line.split(/\s+/);
                if (parts.length < 2)
                    return;

                if (parts[1] === "NA") {
                    containerRect.available = false;
                    containerRect.volume = 0;
                    containerRect.muted = false;
                    return;
                }

                containerRect.available = true;
                var vol = Number(parts[1]);
                if (!isNaN(vol))
                    containerRect.volume = Math.max(0, Math.min(1.5, vol));
                containerRect.muted = parts.length > 2 ? (parts[2] === "1") : false;
            }
        }
    }

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 6

        Image {
            id: volumeIcon

            width: 16
            height: 16
            source: containerRect.iconBase + containerRect.volumeIconName() + ".svg"
            smooth: true
            layer.enabled: true

            layer.effect: ColorOverlay {
                color: containerRect.fgColor
            }
        }

        Text {
            id: volumeText

            text: containerRect.available ? (Math.round(containerRect.volume * 100) + "%") : "N/A"
            color: containerRect.fgColor
            font.bold: true
        }

        Rectangle {
            id: volumeBar

            width: 48
            height: 4
            radius: 2
            color: containerRect.barBg
            opacity: containerRect.available ? 1 : 0.5

            Rectangle {
                id: volumeFill

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: Math.max(2, parent.width * Math.max(0, Math.min(1, containerRect.volume)))
                radius: 2
                color: containerRect.muted ? "#7f7f7f" : containerRect.fgColor

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
        acceptedButtons: Qt.LeftButton

        onWheel: {
            if (!containerRect.available)
                return;
            if (wheel.angleDelta.y > 0)
                containerRect.stepUp();
            else if (wheel.angleDelta.y < 0)
                containerRect.stepDown();
        }

        onClicked: {
            if (!containerRect.available)
                return;
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        }
    }
}
