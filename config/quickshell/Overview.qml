import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "./services"

Scope {
    id: overviewScope
    
    IpcHandler {
        target: "overview"

        function toggle(): void {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    
    PanelWindow {
        id: panelWindow
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        visible: GlobalStates.overviewOpen
        
        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
        
        // Semi-transparent background overlay
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
                    GlobalStates.overviewOpen = false
                }
            }
        }
        
        FocusScope {
            anchors.fill: parent
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
