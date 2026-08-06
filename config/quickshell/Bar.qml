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

            ActiveWindowWidget {
                id: activeWindowWidget
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
            }
            
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
                anchors.right: dndWidget.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 8
                visible: UPower.displayDevice.percentage != 0
            }

            AppIndicatorWidget {
                id: appIndicatorWidget
                trayParentWindow: panelWindow
                anchors.right: batteryWidget.visible ? batteryWidget.left : dndWidget.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: batteryWidget.visible ? 8 : 10
            }

            DndWidget {
                id: dndWidget
                anchors.right: caffeineWidget.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 8
            }

            CaffeineWidget {
                id: caffeineWidget
                anchors.right: recordingWidget.visible ? recordingWidget.left : numLockWidget.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 8
            }

            RecordingWidget {
                id: recordingWidget
                anchors.right: numLockWidget.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 8
            }

            NumLockWidget {
                id: numLockWidget
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
            }

            MouseArea {
                id: brightnessCorner

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 120
                z: 1000
                acceptedButtons: Qt.NoButton

                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0) {
                        Quickshell.execDetached(["bash", "-lc", "brightnessctl set +5% >/dev/null && value=$(brightnessctl -m | awk -F',' 'NR==1 { gsub(/%/, \"\", $4); print $4 }'); [ -n \"$value\" ] && quickshell ipc call osd brightness \"$value\""]);
                    } else if (wheel.angleDelta.y < 0) {
                        Quickshell.execDetached(["bash", "-lc", "brightnessctl set 5%- >/dev/null && value=$(brightnessctl -m | awk -F',' 'NR==1 { gsub(/%/, \"\", $4); print $4 }'); [ -n \"$value\" ] && quickshell ipc call osd brightness \"$value\""]);
                    }
                }
            }

            MouseArea {
                id: volumeCorner

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 120
                z: -1
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0) {
                        Quickshell.execDetached(["bash", "-lc", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && value=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{ print $2 }'); [ -n \"$value\" ] && quickshell ipc call osd volume \"$value\""]);
                    } else if (wheel.angleDelta.y < 0) {
                        Quickshell.execDetached(["bash", "-lc", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && value=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{ print $2 }'); [ -n \"$value\" ] && quickshell ipc call osd volume \"$value\""]);
                    }
                }

                onClicked: {
                    Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                }
            }

        }

    }

}
