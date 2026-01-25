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

            // screen: modelData
            implicitHeight: 40

            anchors {
                top: true
                left: true
                right: true
            }
            
            WorkspacesWidget {
                anchors.left: parent.center
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
            }

            ClockWidget {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
            }

            BatteryWidget {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
            }

        }

    }

}
