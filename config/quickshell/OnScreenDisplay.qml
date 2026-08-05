import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

Scope {
    id: root

    IpcHandler {
        target: "osd"

        function brightness(): void {
            root.trigger("brightness");
            ipcBrightnessRefresh.restart();
        }
    }

    property var visibleKinds: []
    readonly property bool open: visibleKinds.length > 0
    property real volumeValue: 0
    property bool volumeMuted: false
    property bool volumeAvailable: true
    property real brightnessValue: 0
    property bool brightnessAvailable: true
    property bool preferPipewire: true
    property bool usePipewire: preferPipewire && Pipewire.ready
    property var sink: Pipewire.defaultAudioSink
    property bool _audioInitialized: false
    property bool _brightnessInitialized: false
    property string backlightDevice: ""
    property string brightnessPath: ""
    property string maxBrightnessPath: ""
    property int maxBrightness: 100
    property real _lastVolumeValue: -1
    property bool _lastVolumeMuted: false
    property int _lastBrightnessPercent: -1

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
        var orderedKinds = root.visibleKinds.filter(item => item !== kind);
        orderedKinds.push(kind);
        root.visibleKinds = orderedKinds;

        if (kind === "brightness")
            brightnessTimeout.restart();
        else
            volumeTimeout.restart();
    }

    function dismiss(kind) {
        root.visibleKinds = root.visibleKinds.filter(item => item !== kind);
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

    function syncVolume(triggerOsd) {
        var node = root.sink;
        var audio = node?.audio ?? null;
        root.volumeAvailable = (node?.ready ?? false) && root.usePipewire;

        if (!audio) {
            root.volumeValue = 0;
            root.volumeMuted = false;
            return;
        }

        var vol = audio.volume;
        var muted = audio.muted;
        if (!isNaN(vol))
            root.applyVolume(vol, muted, "pipewire", triggerOsd);
    }

    function applyVolume(value, muted, source, triggerOsd) {
        var normalized = Math.max(0, Math.min(1.5, value));
        if (normalized === root._lastVolumeValue && muted === root._lastVolumeMuted)
            return;

        root._lastVolumeValue = normalized;
        root._lastVolumeMuted = muted;
        root.volumeAvailable = true;
        root.volumeValue = normalized;
        root.volumeMuted = muted;

        console.log("[OSD] Volume changed (" + source + "):", root.volumeValue, "muted:", root.volumeMuted);

        if (triggerOsd && root.volumeAvailable)
            root.trigger("volume");
    }

    function initVolume() {
        root.syncVolume(false);
        root._audioInitialized = true;
    }

    function attachSink() {
        console.log("[OSD] Pipewire ready:", Pipewire.ready, "defaultAudioSink:", root.sink);
        root._audioInitialized = false;
        root.syncVolume(false);
    }

    function handleVolumeEvent() {
        if (!root._audioInitialized) {
            root.initVolume();
            return;
        }
        root.syncVolume(true);
    }

    function updateMaxBrightness() {
        if (!root.maxBrightnessPath)
            return;
        var rawMax = Number(maxBrightnessView.text().trim());
        if (!isNaN(rawMax) && rawMax > 0) {
            root.maxBrightness = rawMax;
        }
    }

    function updateBrightness(triggerOsd) {
        if (!root.brightnessPath)
            return;
        var raw = Number(brightnessView.text().trim());
        if (isNaN(raw)) {
            root.brightnessAvailable = false;
            return;
        }

        root.brightnessAvailable = true;
        var maxVal = root.maxBrightness > 0 ? root.maxBrightness : 100;
        var pct = Math.round((raw / maxVal) * 100);
        root.applyBrightnessPercent(pct, "sysfs", triggerOsd && root._brightnessInitialized);

        if (!root._brightnessInitialized) {
            root._brightnessInitialized = true;
        }
    }

    function applyBrightnessPercent(percent, source, triggerOsd) {
        var pct = Math.max(0, Math.min(100, Math.round(percent)));
        if (pct === root._lastBrightnessPercent)
            return;

        root._lastBrightnessPercent = pct;
        root.brightnessAvailable = true;
        root.brightnessValue = pct / 100;

        console.log("[OSD] Brightness changed (" + source + "):", pct + "%");

        if (triggerOsd)
            root.trigger("brightness");
    }

    Timer {
        id: volumeTimeout
        interval: 2500
        repeat: false
        running: false
        onTriggered: root.dismiss("volume")
    }

    Timer {
        id: brightnessTimeout
        interval: 2500
        repeat: false
        running: false
        onTriggered: root.dismiss("brightness")
    }

    Timer {
        id: ipcBrightnessRefresh
        interval: 80
        repeat: false
        running: false
        onTriggered: {
            if (root.brightnessPath) {
                brightnessView.reload();
                root.updateBrightness(false);
            }
        }
    }

    Timer {
        id: pipewirePoll
        interval: 200
        repeat: true
        running: root.usePipewire
        onTriggered: {
            var audio = root.sink?.audio ?? null;
            if (!audio || !(root.sink?.ready ?? false))
                return;
            var vol = audio.volume;
            var muted = audio.muted;
            if (isNaN(vol))
                return;
            if (vol !== root._lastVolumeValue || muted !== root._lastVolumeMuted)
                root.handleVolumeEvent();
        }
    }

    Process {
        id: volumeFallbackProc

        running: !root.usePipewire
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

                var vol = Number(parts[1]);
                root.volumeMuted = parts.length > 2 ? (parts[2] === "1") : false;

                if (!isNaN(vol))
                    root.applyVolume(vol, root.volumeMuted, "fallback", true);
            }
        }
    }

    Process {
        id: backlightProc

        command: [
            "bash",
            "-lc",
            "dev=$(brightnessctl -m 2>/dev/null | awk -F',' 'NR==1{print $1}'); " +
            "if [ -n \"$dev\" ] && [ -d \"/sys/class/backlight/$dev\" ]; then " +
            "printf '%s\\n' \"$dev\"; " +
            "else ls -1 /sys/class/backlight 2>/dev/null | head -n1; fi"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var device = data.trim();
                if (!device) {
                    root.brightnessAvailable = false;
                    return;
                }
                root.backlightDevice = device;
            }
        }
    }

    onBacklightDeviceChanged: {
        if (!root.backlightDevice)
            return;
        root.brightnessPath = "/sys/class/backlight/" + root.backlightDevice + "/brightness";
        root.maxBrightnessPath = "/sys/class/backlight/" + root.backlightDevice + "/max_brightness";
        brightnessView.reload();
        maxBrightnessView.reload();
    }

    FileView {
        id: brightnessView

        path: root.brightnessPath
        preload: true
        watchChanges: true

        onLoaded: root.updateBrightness(false)
        onFileChanged: root.updateBrightness(true)
    }

    FileView {
        id: maxBrightnessView

        path: root.maxBrightnessPath
        preload: true
        watchChanges: true

        onLoaded: root.updateMaxBrightness()
        onFileChanged: {
            root.updateMaxBrightness();
            root.updateBrightness(false);
        }
    }

    Process {
        id: brightnessFallbackProc

        running: true
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

                var pct = Number(parts[1]);
                if (!isNaN(pct)) {
                    root.applyBrightnessPercent(pct, "brightnessctl", root._brightnessInitialized);
                    if (!root._brightnessInitialized)
                        root._brightnessInitialized = true;
                }
            }
        }
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            root.attachSink();
        }
        function onReadyChanged() {
            root.attachSink();
        }
    }

    Connections {
        target: root.sink ?? null
        function onReadyChanged() {
            root.attachSink();
        }
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumesChanged() {
            root.handleVolumeEvent();
        }
        function onMutedChanged() {
            root.handleVolumeEvent();
        }
    }

    Component.onCompleted: root.attachSink()

    PwObjectTracker {
        objects: [root.sink, root.sink?.audio]
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
        implicitWidth: osdColumn.implicitWidth
        implicitHeight: osdColumn.implicitHeight

        Column {
            id: osdColumn
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: root.visibleKinds

                delegate: Rectangle {
                    required property string modelData
                    readonly property string kind: modelData

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
                            source: root.iconBase + (kind === "brightness" ? root.brightnessIconName() : root.volumeIconName()) + ".svg"
                            smooth: true
                            layer.enabled: true

                            layer.effect: ColorOverlay {
                                color: root.fgColor
                            }
                        }

                        Text {
                            id: osdLabel

                            text: kind === "brightness" ? "Brightness" : "Volume"
                            color: root.fgColor
                            font.bold: true
                        }

                        Text {
                            id: osdValue

                            text: kind === "brightness" ? root.formatPercent(root.brightnessValue) : root.formatPercent(root.volumeValue)
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
                                width: Math.max(2, parent.width * Math.max(0, Math.min(1, kind === "brightness" ? root.brightnessValue : root.volumeValue)))
                                radius: 2
                                color: kind === "volume" && root.volumeMuted ? "#7f7f7f" : root.fgColor

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
                        onClicked: root.dismiss(kind)
                    }
                }
            }
        }
    }
}
