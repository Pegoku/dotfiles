import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.UPower

Rectangle {
    id: containerRect

    property int padding: 6
    property real percentage: {
        var d = UPower.displayDevice;
        if (!d || !d.ready)
            return 0;

        return d.percentage;
    }
    property real timeToEmpty: {
        var d = UPower.displayDevice;
        if (!d || !d.ready)
            return 0;

        return d.timeToEmpty;
    }
    property real timeToFull: {
        var d = UPower.displayDevice;
        if (!d || !d.ready)
            return 0;

        return d.timeToFull;
    }
    property bool charging: {
        var d = UPower.displayDevice;
        if (!d || !d.ready)
            return false;

        return d.timeToFull > 0;
    }
    property color iconColor: {
        containerRect.percentage > 0.2 ? "#f2f2f2" : containerRect.percentage > 0.1 ? "#f5a623" : "#ff3b30";
    }
    property string tooltipText: {
        var pct = Math.round(containerRect.percentage * 100);
        if (pct < 0)
            pct = 0;

        var isFull = pct >= 100;
        var state = containerRect.charging ? "Charging" : "Discharging";
        if (isFull)
            state = "Full";

        var eta = "";
        if (!isFull) {
            if (containerRect.charging && containerRect.timeToFull > 0)
                eta = formatEta(containerRect.timeToFull) + " to full";
            else if (!containerRect.charging && containerRect.timeToEmpty > 0)
                eta = formatEta(containerRect.timeToEmpty) + " remaining";
        }
        return eta ? state + " · " + pct + "%" + " · " + eta : state + " · " + pct + "%";
    }

    function batteryIconName() {
        var pct = Math.round(containerRect.percentage * 100);
        var step = Math.max(0, Math.min(100, Math.round(pct / 10) * 10));
        if (containerRect.charging && step === 100)
            return "battery-level-100-charged-symbolic";

        return "battery-level-" + step + (containerRect.charging ? "-charging-symbolic" : "-symbolic");
    }

    function formatEta(seconds) {
        if (!seconds || seconds <= 0)
            return "";

        var totalSeconds = Math.round(seconds);
        var totalMinutes = Math.floor(totalSeconds / 60);
        var hours = Math.floor(totalMinutes / 60);
        var minutes = totalMinutes % 60;
        if (hours > 0)
            return hours + "h " + minutes + "m";

        return minutes + "m";
    }

    anchors.verticalCenter: parent.verticalCenter
    radius: 12
    color: "#1c1c1c"
    opacity: 0.85
    layer.enabled: true
    width: contentRow.implicitWidth + padding * 2
    height: contentRow.implicitHeight + padding * 2
    ToolTip.visible: hoverArea.containsMouse && containerRect.tooltipText.length > 0
    ToolTip.text: containerRect.tooltipText
    ToolTip.delay: 150
    ToolTip.timeout: 0

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 0

        Image {
            id: battIcon

            width: 18
            height: 18
            source: "file:///usr/share/icons/Adwaita/symbolic/status/" + containerRect.batteryIconName() + ".svg"
            smooth: true
            layer.enabled: true

            layer.effect: ColorOverlay {
                color: containerRect.iconColor
            }

        }

    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

}
