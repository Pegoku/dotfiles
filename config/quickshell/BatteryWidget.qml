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

    Text {
        id: battText

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: (UPower.displayDevice.ready ? (UPower.displayDevice.changeRate > 0 ? "Discharging " : "Charging ") + Math.round(UPower.displayDevice.percentage*100) + "%" : "")
        color: "white"
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            
        }
    }

}
