import QtQuick

Rectangle {
    id: root

    property int number: 0
    property bool active: false
    property bool occupied: false
    signal pressed(int number)

    property color textColor: "#c8c8c8"
    property color activeColor: "#5b7cfa"
    property color activeDotColor: "#e6ecff"
    property color occupiedDotColor: "#5a5a5a"

    width: 24
    height: 20
    radius: 10
    color: active ? activeColor : occupied ? occupiedDotColor : "transparent"

    Rectangle {
        id: activeDot
        z: 3
        width: 6
        height: 6
        radius: 3
        color: activeDotColor
        anchors.centerIn: parent
        visible: active
    }

    Text {
        id: textContent
        z: 3

        text: number
        color: textColor
        font.bold: occupied
        font.pixelSize: 12
        anchors.centerIn: parent
        visible: !active
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.pressed(root.number)
    }
}
