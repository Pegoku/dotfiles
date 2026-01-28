import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool open: false
    property string currentKind: "volume"
    property real volumeValue: 0
    property bool volumeMuted: false
    property bool volumeAvailable: true
    property real brightnessValue: 0
    property bool brightnessAvailable: true

    property string iconBase: "file:///usr/share/icons/Adwaita/symbolic/status/"
    property color fgColor: "#f2f2f2"
    property color bgColor: "#1c1c1c"
    property color barBg: "#3a3a3a"
    property int topOffset: 56

    readonly property var focusedScreen: {
        var screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name);
        return screen ?? Quickshell.screens[0];
    }

    function trigger(kind) {
        root.currentKind = kind;
        root.open = true;
        osdTimeout.restart();
    }

    function formatPercent(value) {
        var pct = Math.round(value * 100);
        if (pct < 0)
            pct = 0;
        return pct + "%";
    }

    function volumeIconName() {
        if (!root.volumeAvailable)
            return "audio-volume-muted-symbolic";
        if (root.volumeMuted || root.volumeValue <= 0.01)
            return "audio-volume-muted-symbolic";
        if (root.volumeValue > 1.0)
            return "audio-volume-overamplified-symbolic";
        if (root.volumeValue < 0.33)
            return "audio-volume-low-symbolic";
        if (root.volumeValue < 0.66)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    function brightnessIconName() {
        return "display-brightness-symbolic";
    }

    Timer {
        id: osdTimeout
        interval: 2500
        repeat: false
        running: false
        onTriggered: root.open = false
    }

    Process {
        id: volumeProc

        command: [
            "bash",
            "-lc",
            "prev=; prevm=; " +
            "while true; do " +
            "line=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
            "if [ -z \"$line\" ]; then echo 'VOL NA'; else " +
            "val=$(echo \"$line\" | awk '{print $2}'); " +
            "muted=$(echo \"$line\" | grep -q MUTED && echo 1 || echo 0); " +
            "if [ \"$val\" != \"$prev\" ] || [ \"$muted\" != \"$prevm\" ]; then " +
            "echo \"VOL $val $muted\"; prev=$val; prevm=$muted; fi; " +
            "fi; " +
            "sleep 0.2; done"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line || !line.startsWith("VOL "))
                    return;

                var parts = line.split(/\s+/);
                if (parts.length < 2)
                    return;

                if (parts[1] === "NA") {
                    root.volumeAvailable = false;
                    root.volumeValue = 0;
                    root.volumeMuted = false;
                    return;
                }

                root.volumeAvailable = true;
                var vol = Number(parts[1]);
                if (!isNaN(vol))
                    root.volumeValue = Math.max(0, Math.min(1.5, vol));
                root.volumeMuted = parts.length > 2 ? (parts[2] === "1") : false;

                if (root.volumeAvailable)
                    root.trigger("volume");
            }
        }
    }

    Process {
        id: brightnessProc

        command: [
            "bash",
            "-lc",
            "prev=; " +
            "while true; do " +
            "val=$(brightnessctl -m 2>/dev/null | awk -F',' '{gsub(/%/,\"\",$5); print $5}'); " +
            "if [ -z \"$val\" ]; then echo 'BRT NA'; else " +
            "if [ \"$val\" != \"$prev\" ]; then echo \"BRT $val\"; prev=$val; fi; fi; " +
            "sleep 0.3; done"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line || !line.startsWith("BRT "))
                    return;

                var parts = line.split(/\s+/);
                if (parts.length < 2)
                    return;

                if (parts[1] === "NA") {
                    root.brightnessAvailable = false;
                    root.brightnessValue = 0;
                    return;
                }

                root.brightnessAvailable = true;
                var pct = Number(parts[1]);
                if (!isNaN(pct))
                    root.brightnessValue = Math.max(0, Math.min(1, pct / 100));

                if (root.brightnessAvailable)
                    root.trigger("brightness");
            }
        }
    }

    PanelWindow {
        id: osdWindow
        screen: root.focusedScreen
        color: "transparent"
        visible: root.open

        WlrLayershell.namespace: "quickshell:osd"
        WlrLayershell.layer: WlrLayer.Overlay
        anchors {
            top: true
        }
        margins {
            top: root.topOffset
        }
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        implicitWidth: osdWrapper.implicitWidth
        implicitHeight: osdWrapper.implicitHeight

        Item {
            id: osdWrapper
            anchors.centerIn: parent
            implicitWidth: osdPill.implicitWidth
            implicitHeight: osdPill.implicitHeight

            Rectangle {
                id: osdPill

                radius: 999
                color: root.bgColor
                opacity: 0.9
                layer.enabled: true
                implicitWidth: contentRow.implicitWidth + 20
                implicitHeight: contentRow.implicitHeight + 10

                Row {
                    id: contentRow

                    anchors.centerIn: parent
                    spacing: 10

                    Image {
                        id: osdIcon

                        width: 16
                        height: 16
                        source: root.iconBase + (root.currentKind === "brightness" ? root.brightnessIconName() : root.volumeIconName()) + ".svg"
                        smooth: true
                        layer.enabled: true

                        layer.effect: ColorOverlay {
                            color: root.fgColor
                        }
                    }

                    Text {
                        id: osdLabel

                        text: root.currentKind === "brightness" ? "Brightness" : "Volume"
                        color: root.fgColor
                        font.bold: true
                    }

                    Text {
                        id: osdValue

                        text: root.currentKind === "brightness" ? root.formatPercent(root.brightnessValue) : root.formatPercent(root.volumeValue)
                        color: root.fgColor
                    }

                    Rectangle {
                        id: osdBar

                        width: 90
                        height: 4
                        radius: 2
                        color: root.barBg

                        Rectangle {
                            id: osdFill

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            width: Math.max(2, parent.width * Math.max(0, Math.min(1, root.currentKind === "brightness" ? root.brightnessValue : root.volumeValue)))
                            radius: 2
                            color: root.currentKind === "volume" && root.volumeMuted ? "#7f7f7f" : root.fgColor

                            Behavior on width {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.open = false
                }
            }
        }
    }
}
