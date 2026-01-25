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
                radius: 12
                width: workspaceRow.implicitWidth + workspaceRow.anchors.margins * 2
                color: "#1c1c1c"
                opacity: 0.85
                height: workspaceRow.implicitHeight + workspaceRow.anchors.margins * 2

                Row {
                    id: workspaceRow

                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    Repeater {
                        model: 10
                        delegate: WorkspaceButton {
                            required property int index
                            number: index + 1
                            workspace: Hyprland.workspaces.values.find(ws => ws.id === index + 1) ?? null
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
