import QtQuick
import Quickshell.Hyprland

Rectangle {
    required property var workspace
    property int number: 0
    property bool hasWindows: workspace && workspace.toplevels && workspace.toplevels.count > 0
    property bool isActive: workspace && workspace.active

    property color textColor: "#c8c8c8"
    property color activeColor: "#5b7cfa"
    property color activeDotColor: "#e6ecff"
    property color occupiedDotColor: "#5a5a5a"

    width: 20
    height: 20
    radius: 10
    color: isActive ? activeColor : "transparent"

    Rectangle {
        id: activeDot
        width: 6
        height: 6
        radius: 3
        color: activeDotColor
        anchors.centerIn: parent
        visible: isActive
    }

    Rectangle {
        id: occupiedDot
        width: 4
        height: 4
        radius: 2
        color: occupiedDotColor
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        visible: hasWindows && !isActive
    }

    Text {
        id: textContent

        text: number
        color: textColor
        font.bold: hasWindows
        anchors.centerIn: parent
        visible: !isActive
    }
}
