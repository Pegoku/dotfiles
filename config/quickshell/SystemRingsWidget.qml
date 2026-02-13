import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import Quickshell.Io

Item {
    id: root

    property real cpuUsage: 0
    property real memUsage: 0
    property real gpuUsage: -1
    property real diskUsage: 0

    property color ringBg: "#3a3a3a"
    property color ringFg: "#f2f2f2"
    property string iconBase: "file:///usr/share/icons/Adwaita/symbolic/"
    property string cpuIcon: iconBase + "categories/applications-system-symbolic.svg"
    property string memIcon: iconBase + "devices/media-flash-symbolic.svg"
    property string gpuIcon: iconBase + "devices/video-display-symbolic.svg"
    property string diskIcon: iconBase + "devices/drive-harddisk-system-symbolic.svg"

    readonly property bool gpuPresent: root.gpuUsage >= 0

    width: ringsRow.implicitWidth
    height: ringsRow.implicitHeight

    Process {
        id: metricsProc

        command: [
            "bash",
            "-lc",
            "while true; do " +
            "echo \"CPU $(head -n1 /proc/stat)\"; " +
            "awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {print \"MEM \" t \" \" a}' /proc/meminfo; " +
            "df -P / | awk 'NR==2 {print \"DISK \" $2 \" \" $4}'; " +
            "gpu=\"\"; " +
            "for f in /sys/class/drm/card2/device/gpu_busy_percent; do if [ -r \"$f\" ]; then gpu=$(cat \"$f\"); break; fi; done; " +
            "if [ -z \"$gpu\" ] && command -v nvidia-smi >/dev/null 2>&1; then gpu=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n1); fi; " +
            "if [ -z \"$gpu\" ]; then echo \"GPU NA\"; else echo \"GPU $gpu\"; fi; " +
            "sleep 1; done"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line)
                    return;

                if (line.startsWith("CPU ")) {
                    root.updateCpu(line.substring(4));
                } else if (line.startsWith("MEM ")) {
                    root.updateMem(line.substring(4));
                } else if (line.startsWith("DISK ")) {
                    root.updateDisk(line.substring(5));
                } else if (line.startsWith("GPU ")) {
                    root.updateGpu(line.substring(4));
                }
            }
        }
    }

    property bool _hasPrevCpu: false
    property real _prevCpuTotal: 0
    property real _prevCpuIdle: 0

    function updateCpu(line) {
        var parts = line.trim().split(/\s+/);
        if (parts.length < 5 || parts[0] !== "cpu")
            return;

        var total = 0;
        for (var i = 1; i < parts.length; i++)
            total += Number(parts[i]);

        var idle = Number(parts[4]) + (parts.length > 5 ? Number(parts[5]) : 0);

        if (root._hasPrevCpu) {
            var diffTotal = total - root._prevCpuTotal;
            var diffIdle = idle - root._prevCpuIdle;
            if (diffTotal > 0)
                root.cpuUsage = Math.max(0, Math.min(1, 1 - diffIdle / diffTotal));
        }

        root._prevCpuTotal = total;
        root._prevCpuIdle = idle;
        root._hasPrevCpu = true;
    }

    function updateMem(line) {
        var parts = line.trim().split(/\s+/);
        if (parts.length < 2)
            return;

        var total = Number(parts[0]);
        var avail = Number(parts[1]);
        if (total > 0)
            root.memUsage = Math.max(0, Math.min(1, 1 - (avail / total)));
    }

    function updateDisk(line) {
        var parts = line.trim().split(/\s+/);
        if (parts.length < 2)
            return;

        var total = Number(parts[0]);
        var avail = Number(parts[1]);
        if (total > 0)
            root.diskUsage = Math.max(0, Math.min(1, 1 - (avail / total)));
    }

    function updateGpu(line) {
        if (line === "NA") {
            root.gpuUsage = -1;
            return;
        }

        var val = Number(line);
        if (isNaN(val)) {
            root.gpuUsage = -1;
            return;
        }

        root.gpuUsage = Math.max(0, Math.min(1, val / 100));
    }

    Row {
        id: ringsRow

        anchors.centerIn: parent
        spacing: 6

        RingIndicator {
            iconSource: root.cpuIcon
            label: "CPU"
            value: root.cpuUsage
            visible: true
        }

        RingIndicator {
            iconSource: root.memIcon
            label: "RAM"
            value: root.memUsage
            visible: true
        }

        RingIndicator {
            iconSource: root.gpuIcon
            label: "GPU"
            value: root.gpuUsage
            visible: root.gpuPresent
        }

        RingIndicator {
            iconSource: root.diskIcon
            label: "Disk usage"
            value: root.diskUsage
            visible: true
        }
    }

    component RingIndicator: Item {
        id: ring

        property string iconSource: ""
        property string label: ""
        property real value: 0
        property bool hovered: hoverArea.containsMouse

        width: 24
        height: 24

        ToolTip.visible: ring.hovered
        ToolTip.delay: 150
        ToolTip.timeout: 0
        ToolTip.text: label + " · " + Math.round(value * 100) + "%"

        Behavior on value {
            NumberAnimation {
                duration: 350
                easing.type: Easing.InOutQuad
            }
        }

        Canvas {
            id: ringCanvas

            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var stroke = 3;
                var radius = Math.min(width, height) / 2 - stroke / 2;
                var centerX = width / 2;
                var centerY = height / 2;
                var start = -Math.PI / 2;
                var end = start + Math.PI * 2 * ring.value;

                ctx.lineWidth = stroke;
                ctx.lineCap = "round";

                ctx.strokeStyle = root.ringBg;
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, 0, Math.PI * 2, false);
                ctx.stroke();

                ctx.strokeStyle = root.ringFg;
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, start, end, false);
                ctx.stroke();
            }
        }

        Image {
            anchors.centerIn: parent
            width: 12
            height: 12
            source: ring.iconSource
            smooth: true
            layer.enabled: true

            layer.effect: ColorOverlay {
                color: root.ringFg
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        onValueChanged: ringCanvas.requestPaint()
        onWidthChanged: ringCanvas.requestPaint()
        onHeightChanged: ringCanvas.requestPaint()
    }
}
