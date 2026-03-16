import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "./services"

Scope {
    id: overviewScope

    readonly property string focusedMonitorName: Hyprland.focusedMonitor?.name ?? ""
    
    IpcHandler {
        target: "overview"

        function toggle(): void {
            GlobalStates.toggleOverview();
        }
    }
    
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow
            required property var modelData
            screen: modelData
            readonly property bool isFocusedScreen: panelWindow.screen?.name === overviewScope.focusedMonitorName
            visible: GlobalStates.overviewOpen

            WlrLayershell.namespace: "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: GlobalStates.overviewOpen && isFocusedScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"

            mask: Region {
                item: GlobalStates.overviewOpen ? overlayBackground : null
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                id: overlayBackground
                anchors.fill: parent
                color: "#000000"
                opacity: GlobalStates.overviewOpen ? 0.7 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        GlobalStates.setOverviewOpen(false)
                    }
                }
            }

            FocusScope {
                anchors.fill: parent
                focus: GlobalStates.overviewOpen && panelWindow.isFocusedScreen
            }

            OverviewWidget {
                id: overviewWidget
                screen: panelWindow.screen
                anchors.centerIn: parent
                visible: GlobalStates.overviewOpen

                opacity: GlobalStates.overviewOpen ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                transform: Scale {
                    origin.x: overviewWidget.width / 2
                    origin.y: overviewWidget.height / 2
                    xScale: GlobalStates.overviewOpen ? 1 : 0.9
                    yScale: GlobalStates.overviewOpen ? 1 : 0.9

                    Behavior on xScale {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on yScale {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
