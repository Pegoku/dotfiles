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
            id: panelWindow
            required property var modelData
            screen: modelData
            
            implicitHeight: 40

            anchors {
                top: true
                left: true
                right: true
            }

            color: root.accentColor
            
            SystemRingsWidget {
                id: systemRingsWidget
                anchors.right: nowPlayingWidget.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 8
            }

            NowPlayingWidget {
                id: nowPlayingWidget
                anchors.right: workspacesWidget.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
            }

            WorkspacesWidget {
                id: workspacesWidget
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
            }

            ClockWidget {
                id: clockWidget
                anchors.left: workspacesWidget.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
            }

            BatteryWidget {
                id: batteryWidget
                anchors.right: numLockWidget.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 8
                visible: UPower.displayDevice.percentage != 0
            }

            NetworkWidget {
                id: networkWidget
                anchors.right: batteryWidget.visible ? batteryWidget.left : numLockWidget.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: batteryWidget.visible ? 8 : 10
            }

            AppIndicatorWidget {
                id: appIndicatorWidget
                trayParentWindow: panelWindow
                anchors.right: networkWidget.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 8
            }

            NumLockWidget {
                id: numLockWidget
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
            }

        }

    }

}
