import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower

Scope {
    id: root

    property string accentColor: '#6c072952'

    // Process {
    //     id: colorReader
    //     command: ["cat", "/home/pegoku/.local/state/hypr/user/color.txt"]
    //     running: true
        
    //     stdout: SplitParser {
    //         onRead: data => {
    //             root.accentColor = data.trim().split("")
    //             console.log("Read color:", data.trim() + "90")
    //         }
    //     }
    // }

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

            color: root.accentColor
            
            WorkspacesWidget {
                id: workspacesWidget
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
            }

            ClockWidget {
                anchors.left: workspacesWidget.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
            }

            BatteryWidget {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
                visible: UPower.displayDevice.percentage != 0
            }

        }

    }

}
