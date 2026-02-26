import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Rectangle {
    id: containerRect

    property int padding: 6

    anchors.verticalCenter: parent.verticalCenter
    radius: 12
    color: "#1c1c1c"
    opacity: 0.85
    visible: trayRow.implicitWidth > 0
    width: trayRow.implicitWidth + padding * 2
    height: trayRow.implicitHeight + padding * 2

    Row {
        id: trayRow

        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: SystemTray.items

            delegate: Rectangle {
                id: trayButton
                required property var modelData

                width: 18
                height: 18
                radius: 5
                color: trayMouse.containsMouse ? "#3a3a3a" : "transparent"

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 16
                    source: modelData.icon
                    asynchronous: true
                }

                MouseArea {
                    id: trayMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton)
                            modelData.activate();
                        else if (mouse.button === Qt.MiddleButton)
                            modelData.secondaryActivate();
                        else if (mouse.button === Qt.RightButton)
                            modelData.secondaryActivate();
                    }

                    onWheel: wheel => {
                        modelData.scroll(wheel.angleDelta.y, false);
                        wheel.accepted = true;
                    }
                }

            }
        }
    }
}
