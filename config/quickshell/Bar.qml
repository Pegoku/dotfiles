import QtQuick
import Quickshell
import Quickshell.Hyprland

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            implicitHeight: 30

            anchors {
                top: true
                left: true
                right: true
            }
            
            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 20
                Repeater {
                    model: Hyprland.workspaces

                    Rectangle {
                        width: textContent.implicitWidth + 10
                        height: parent.height
                        // color: modelData.active ? "#444" : "transparent"

                        Text {
                            id: textContent
                            text: modelData.name
                            color: "black"
                            font.bold: modelData.active
                            anchors.centerIn: parent
                        }
                    }

                    // WorkspaceButton {
                    //     workspace: modelData
                    // }
                }
            }
            // ClockWidget {
            //     anchors.centerIn: parent
            // }

            BatteryWidget {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
            }

        }

    }

}
