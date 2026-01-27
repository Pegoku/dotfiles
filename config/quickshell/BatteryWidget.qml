import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.UPower

Rectangle {
    id: containerRect

    property int padding: 6
    property real percentage: {
        var d = UPower.displayDevice;
        if (!d || !d.ready) return 0;
        return d.percentage;
    }
    property bool charging: {
        var d = UPower.displayDevice;
        if (!d || !d.ready) return false;
        return d.timeToFull > 0;
    }
    property color iconColor: {
        containerRect.percentage > 0.20 ? "#f2f2f2" : containerRect.percentage > 0.10 ? "#f5a623" : "#ff3b30"
    }
    function batteryIconName() {
        var pct = Math.round(containerRect.percentage * 100);
        var step = Math.max(0, Math.min(100, Math.round(pct / 10) * 10));
        if (containerRect.charging && step === 100) {
            return "battery-level-100-charged-symbolic";
        }
        return "battery-level-" + step + (containerRect.charging
            ? "-charging-symbolic"
            : "-symbolic");
    }

    anchors.verticalCenter: parent.verticalCenter
    radius: 12
    color: "#1c1c1c"
    opacity: 0.85
    layer.enabled: true
    width: contentRow.implicitWidth + padding * 2
    height: contentRow.implicitHeight + padding * 2

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 0

        Image {
            id: battIcon
            width: 18
            height: 18
            source: "file:///usr/share/icons/Adwaita/symbolic/status/"
                + containerRect.batteryIconName() + ".svg"
            smooth: true
            layer.enabled: true
            layer.effect: ColorOverlay {
                color: containerRect.iconColor
            }
        }
    }

}
