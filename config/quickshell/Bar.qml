import QtQuick
import Quickshell
import Quickshell.Hyprland

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            //     anchors.centerIn: parent
            // }

            required property var modelData

            screen: modelData
            implicitHeight: 40

            anchors {
                top: true
                left: true
                right: true
            }

            Rectangle {
                property alias innerRow: workspaceRow

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                radius: 10
                width: 320
                color: "#222"
                opacity: 0.8
                height: workspaceRow.implicitHeight + workspaceRow.anchors.margins * 2

                Row {
                    id: workspaceRow

                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 10

                    Repeater {
                        // WorkspaceButton {
                        //     workspaceName: modelData.name
                        //     isActive: modelData.active
                        // }

                        // anchors.margins: 5
                        model: 10

                        Rectangle {
                            width: textContent.implicitWidth + 10
                            height: 20
                            color: modelData.active ? "#444" : "transparent"
                            radius: 10

                            Text {
                                id: textContent

                                text: modelData.name
                                color: "black"
                                font.bold: modelData.active
                                anchors.centerIn: parent
                            }

                        }

                    }

                }

            }
            // ClockWidget {

            BatteryWidget {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
            }

        }

    }

}
