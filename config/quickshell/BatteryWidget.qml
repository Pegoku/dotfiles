import QtQuick
import Quickshell

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
        text: Batt.chargeRate > 0 ? "Charging " + Batt.percentage + "%" :  "Discharging " + Batt.percentage + "%"
        color: "white"
    }

}
