import QtQuick
import Quickshell
import Quickshell.Services.UPower

Rectangle {
    id: containerRect

    property int padding: 6

    anchors.verticalCenter: parent.verticalCenter
    radius: 12
    color: "#1c1c1c"
    opacity: 0.85
    layer.enabled: true
    width: battText.implicitWidth + padding * 2
    height: battText.implicitHeight + padding * 2

    function formatTime(sec) {
        if (!sec || sec <= 0) return "";
        var hrs = Math.floor(sec / 3600);
        var mins = Math.floor((sec % 3600) / 60);
        if (hrs > 0) return hrs + "h " + mins + "m";
        return mins + "m";
    }

    function batteryText() {
        var d = UPower.displayDevice;
        if (!d || !d.ready) return "";
        var pct = Math.round(d.percentage*100);
        console.log("Battery data:", d.percentage,"%, Time to Full:", d.timeToFull, "Time to Empty:", d.timeToEmpty, "Change Rate:", d.changeRate);
        if (d.timeToFull > 0) {
            var t = formatTime(d.timeToFull);
            return "Charging " + pct + "%" + (t ? " (" + t + " until full)" : "");
        } else {
            var t = formatTime(d.timeToEmpty);
            return "Discharging " + pct + "%" + (t ? " (" + t + " left)" : "");
        }
    }

    Text {
        id: battText

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: containerRect.batteryText()
        color: "white"
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            battText.text = containerRect.batteryText();
        }
    }

}
