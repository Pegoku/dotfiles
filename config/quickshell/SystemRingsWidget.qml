import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import Quickshell.Io

Item {
    id: root

    property real cpuUsage: 0
    property real memUsage: 0
    property var gpuStats: []
    property real diskUsage: 0

    property color ringBg: "#3a3a3a"
    property color ringFg: "#f2f2f2"
    property string iconBase: "file:///usr/share/icons/Adwaita/symbolic/"
    property string cpuIcon: iconBase + "categories/applications-system-symbolic.svg"
    property string memIcon: iconBase + "devices/media-flash-symbolic.svg"
    property string gpuIcon: iconBase + "devices/video-display-symbolic.svg"
    property string diskIcon: iconBase + "devices/drive-harddisk-system-symbolic.svg"

    readonly property bool gpuPresent: root.gpuStats.length > 0

    width: ringsRow.implicitWidth
    height: ringsRow.implicitHeight

    Process {
        id: metricsProc

        command: [
            "python3",
            "-u",
            "-c",
            "import json, os, subprocess, time\n"
            + "\n"
            + "def read_text(path):\n"
            + "    try:\n"
            + "        with open(path, 'r', encoding='utf-8', errors='ignore') as handle:\n"
            + "            return handle.read().strip()\n"
            + "    except OSError:\n"
            + "        return ''\n"
            + "\n"
            + "def gpu_entries():\n"
            + "    if shutil.which('nvtop'):\n"
            + "        try:\n"
            + "            out = subprocess.check_output(['nvtop', '-s'], text=True, stderr=subprocess.DEVNULL)\n"
            + "            data = json.loads(out)\n"
            + "            entries = []\n"
            + "            for index, gpu in enumerate(data, 1):\n"
            + "                name = str(gpu.get('device_name') or '').strip() or f'GPU {index}'\n"
            + "                util = str(gpu.get('gpu_util') or '').strip().rstrip('%')\n"
            + "                try:\n"
            + "                    value = float(util)\n"
            + "                except ValueError:\n"
            + "                    continue\n"
            + "                entries.append((name.replace('||', '/').replace('::', ':'), value))\n"
            + "            if entries:\n"
            + "                return entries\n"
            + "        except Exception:\n"
            + "            pass\n"
            + "\n"
            + "    if shutil.which('nvidia-smi'):\n"
            + "        try:\n"
            + "            out = subprocess.check_output(['nvidia-smi', '--query-gpu=name,utilization.gpu', '--format=csv,noheader,nounits'], text=True, stderr=subprocess.DEVNULL)\n"
            + "            entries = []\n"
            + "            for index, line in enumerate(out.splitlines(), 1):\n"
            + "                parts = [part.strip() for part in line.split(',', 1)]\n"
            + "                if len(parts) != 2:\n"
            + "                    continue\n"
            + "                try:\n"
            + "                    value = float(parts[1])\n"
            + "                except ValueError:\n"
            + "                    continue\n"
            + "                name = parts[0] or f'GPU {index}'\n"
            + "                entries.append((name.replace('||', '/').replace('::', ':'), value))\n"
            + "            if entries:\n"
            + "                return entries\n"
            + "        except Exception:\n"
            + "            pass\n"
            + "\n"
            + "    entries = []\n"
            + "    for index, card in enumerate(sorted(name for name in os.listdir('/sys/class/drm') if name.startswith('card') and name[4:].isdigit()), 1):\n"
            + "        busy = read_text(f'/sys/class/drm/{card}/device/gpu_busy_percent')\n"
            + "        if not busy:\n"
            + "            continue\n"
            + "        try:\n"
            + "            value = float(busy)\n"
            + "        except ValueError:\n"
            + "            continue\n"
            + "        entries.append((f'GPU {index}', value))\n"
            + "    return entries\n"
            + "\n"
            + "import shutil\n"
            + "while True:\n"
            + "    stat = read_text('/proc/stat').splitlines()\n"
            + "    if stat:\n"
            + "        print('CPU ' + stat[0], flush=True)\n"
            + "    mem_total = '0'\n"
            + "    mem_avail = '0'\n"
            + "    for line in read_text('/proc/meminfo').splitlines():\n"
            + "        if line.startswith('MemTotal:'):\n"
            + "            mem_total = line.split()[1]\n"
            + "        elif line.startswith('MemAvailable:'):\n"
            + "            mem_avail = line.split()[1]\n"
            + "    print(f'MEM {mem_total} {mem_avail}', flush=True)\n"
            + "    try:\n"
            + "        st = os.statvfs('/')\n"
            + "        total = st.f_blocks * st.f_frsize\n"
            + "        avail = st.f_bavail * st.f_frsize\n"
            + "        print(f'DISK {total} {avail}', flush=True)\n"
            + "    except OSError:\n"
            + "        pass\n"
            + "    gpus = gpu_entries()\n"
            + "    if gpus:\n"
            + "        print('GPU ' + '||'.join(f'{name}::{value}' for name, value in gpus), flush=True)\n"
            + "    else:\n"
            + "        print('GPU NA', flush=True)\n"
            + "    time.sleep(1)"
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
            root.gpuStats = [];
            return;
        }

        var parts = line.trim().split(/\|\|/);
        var stats = [];

        for (var i = 0; i < parts.length; i++) {
            var fields = parts[i].split("::");
            if (fields.length < 2)
                continue;

            var val = Number(fields[fields.length - 1]);
            if (isNaN(val))
                continue;

            stats.push({
                name: fields.slice(0, fields.length - 1).join("::").trim() || ("GPU " + (stats.length + 1)),
                usage: Math.max(0, Math.min(1, val / 100))
            });
        }

        root.gpuStats = stats;
    }

    function gpuUsages() {
        var usages = [];
        for (var i = 0; i < root.gpuStats.length; i++)
            usages.push(root.gpuStats[i].usage);
        return usages;
    }

    Row {
        id: ringsRow

        anchors.centerIn: parent
        spacing: 6

        RingIndicator {
            iconSource: root.cpuIcon
            label: "CPU"
            values: [root.cpuUsage]
            visible: true
        }

        RingIndicator {
            iconSource: root.memIcon
            label: "RAM"
            values: [root.memUsage]
            visible: true
        }

        RingIndicator {
            iconSource: root.gpuIcon
            label: "GPU"
            values: root.gpuUsages()
            details: root.gpuStats
            visible: root.gpuPresent
        }

        RingIndicator {
            iconSource: root.diskIcon
            label: "Disk usage"
            values: [root.diskUsage]
            visible: true
        }
    }

    component RingIndicator: Item {
        id: ring

        property string iconSource: ""
        property string label: ""
        property var values: []
        property var details: []
        property bool hovered: hoverArea.containsMouse
        readonly property int segmentCount: Math.max(1, Math.min(values.length > 0 ? values.length : 1, 4))
        readonly property string tooltipText: {
            if (ring.details.length > 0) {
                var detailEntries = [];
                for (var i = 0; i < ring.details.length; i++)
                    detailEntries.push(ring.details[i].name + " - " + Math.round(ring.details[i].usage * 100) + "%");
                return detailEntries.join(" | ");
            }

            if (ring.values.length <= 1)
                return label + " - " + Math.round(ring.values.length ? ring.values[0] * 100 : 0) + "%";

            var entries = [];
            for (var j = 0; j < ring.values.length && j < 4; j++)
                entries.push(label + " " + (j + 1) + " - " + Math.round(ring.values[j] * 100) + "%");
            return entries.join(" | ");
        }

        width: 24
        height: 24

        ToolTip.visible: ring.hovered && ring.tooltipText.length > 0
        ToolTip.delay: 150
        ToolTip.timeout: 0
        ToolTip.text: ring.tooltipText

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
                var segmentSpan = (Math.PI * 2) / ring.segmentCount;

                ctx.lineWidth = stroke;
                ctx.lineCap = ring.segmentCount > 1 ? "butt" : "round";

                for (var i = 0; i < ring.segmentCount; i++) {
                    var segmentStart = start + segmentSpan * i;
                    var segmentEnd = segmentStart + segmentSpan;
                    var value = 0;

                    if (i < ring.values.length)
                        value = Math.max(0, Math.min(1, Number(ring.values[i]) || 0));

                    ctx.strokeStyle = root.ringBg;
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, segmentStart, segmentEnd, false);
                    ctx.stroke();

                    if (value <= 0)
                        continue;

                    ctx.strokeStyle = root.ringFg;
                    ctx.beginPath();
                    ctx.arc(centerX, centerY, radius, segmentStart, segmentStart + segmentSpan * value, false);
                    ctx.stroke();
                }
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

        onValuesChanged: ringCanvas.requestPaint()
        onWidthChanged: ringCanvas.requestPaint()
        onHeightChanged: ringCanvas.requestPaint()
    }
}
