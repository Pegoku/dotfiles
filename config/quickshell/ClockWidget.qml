import QtQuick
import "."

Rectangle {
    id: containerRect

    property int padding: 6

    function updateAnchorX() {
        GlobalStates.calendarAnchorX = containerRect.x + containerRect.width / 2;
    }

    anchors.verticalCenter: parent.verticalCenter

    radius: 12
    color: "#1c1c1c"
    opacity: 0.85
    layer.enabled: true

    Text {
        id: clockText
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: Time.time + " - "
        color: "white"
        font.bold: true
    }

    Text {
        id: dayText
        anchors.left: clockText.right
        // anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        text: Time.date
        color: "white"
    }
        // keep left padding only (padding on the left side of the text)
        width: clockText.implicitWidth + dayText.implicitWidth + padding*2
    height: clockText.implicitHeight + padding * 2

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            containerRect.updateAnchorX();
            GlobalStates.nowPlayingOpen = false;
            GlobalStates.calendarOpen = !GlobalStates.calendarOpen;
        }
    }

    onXChanged: containerRect.updateAnchorX()
    onWidthChanged: containerRect.updateAnchorX()
    Component.onCompleted: containerRect.updateAnchorX()

}
