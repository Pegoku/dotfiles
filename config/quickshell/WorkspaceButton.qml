import QtQuick
import Quickshell.Hyprland

Rectangle {

    required property var workspace
    property int number: 0
    // property bool hasWindows: workspace && workspace.toplevels && workspace.toplevels.values.length > 0
    function hasWindows(id = number) {
        if (id < 1 || id > 10) return false;
        var ws = Hyprland.workspaces.values.find((ws) => {
            return ws.id === id;
        });
        return ws && ws.toplevels && ws.toplevels.values.length > 0;
    }
    // property bool isActive: workspace && workspace.active
    function isActive(id = number) {
        if (id < 1 || id > 10) return false;
        var ws = Hyprland.workspaces.values.find((ws) => {
            return ws.id === id;
        });
        return ws && ws.active;
    }

    property color textColor: "#c8c8c8"
    property color activeColor: "#5b7cfa"
    property color activeDotColor: "#e6ecff"
    property color occupiedDotColor: "#5a5a5a"

    width: 20
    height: 20
    radius: 10
    color: isActive() ? activeColor : hasWindows() ? occupiedDotColor : "transparent"

    Rectangle {
        id: activeDot
        width: 6
        height: 6
        radius: 3
        color: activeDotColor
        anchors.centerIn: parent
        visible: isActive()
    }

    Rectangle {
        id: rightConnector
        width: 15
        height: 20
        color: occupiedDotColor
        // anchors.horizontalCenter: parent.horizontalCenter
        anchors.right: parent.right
        anchors.rightMargin: -5
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        visible: !isActive() && !isActive(number+1) && hasWindows(number+1) && hasWindows()
    }

    Rectangle {
        id: leftConnector
        width: 15
        height: 20
        color: occupiedDotColor
        // anchors.horizontalCenter: parent.horizontalCenter
        anchors.left: parent.left
        anchors.leftMargin: -5
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        visible: !isActive() && !isActive(number-1) && hasWindows(number-1) && hasWindows()
    }
    Text {
        id: textContent

        text: number
        color: textColor
        font.bold: hasWindows()
        anchors.centerIn: parent
        visible: !isActive()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
                Hyprland.dispatch("workspace " + number)
                console.log("Switched to workspace " + number);

        }
    }
}
