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
            required property var modelData
            screen: modelData
            
            implicitHeight: networkWidget.menuOpen ? 320 : 40
            exclusiveZone: 40

            anchors {
                top: true
                left: true
                right: true
            }

            color: "transparent"

            Rectangle {
                id: barSurface

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 40
                color: root.accentColor
            }
            
            SystemRingsWidget {
                anchors.right: workspacesWidget.left
                anchors.verticalCenter: barSurface.verticalCenter
                anchors.rightMargin: 10
            }

            WorkspacesWidget {
                id: workspacesWidget
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: barSurface.verticalCenter
                anchors.leftMargin: 10
            }

            ClockWidget {
                id: clockWidget
                anchors.left: workspacesWidget.right
                anchors.verticalCenter: barSurface.verticalCenter
                anchors.leftMargin: 10
            }

            BatteryWidget {
                id: batteryWidget
                anchors.right: parent.right
                anchors.verticalCenter: barSurface.verticalCenter
                anchors.rightMargin: 10
                visible: UPower.displayDevice.percentage != 0
            }

            NetworkWidget {
                id: networkWidget
                anchors.right: batteryWidget.visible ? batteryWidget.left : parent.right
                anchors.verticalCenter: barSurface.verticalCenter
                anchors.rightMargin: batteryWidget.visible ? 8 : 10
            }

        }

    }

}
