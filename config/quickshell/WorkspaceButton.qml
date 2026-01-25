import QtQuick
import Quickshell.Hyprland

Rectangle {
    required property var workspace
    property int number: 0

    width: 20
    height: 20
    radius: 10
    color: workspace && workspace.active ? "lightblue" : "gray"

    Text {
        id: textContent

        text: workspace ? String(workspace.name) : String(number)
        color: "black"
        font.bold: workspace && workspace.active
        anchors.centerIn: parent
    }
}
