pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "./services"

Item {
    id: root
    required property var screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int workspacesShown: 9 // 3x3 grid
    readonly property int rows: 3
    readonly property int columns: 3
    readonly property real scale: 0.15
    
    property real workspaceImplicitWidth: monitor.width * scale
    property real workspaceImplicitHeight: monitor.height * scale
    property real workspaceSpacing: 10
    property real padding: 20
    
    implicitWidth: background.implicitWidth + padding * 2
    implicitHeight: background.implicitHeight + padding * 2
    
    Rectangle {
        id: background
        anchors.centerIn: parent
        
        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: 16
        color: "#1e1e1e"
        border.color: "#3a3a3a"
        border.width: 2
        
        Column {
            id: workspaceColumnLayout
            anchors.centerIn: parent
            spacing: workspaceSpacing
            
            Repeater {
                model: root.rows
                delegate: Row {
                    id: row
                    required property int index
                    spacing: workspaceSpacing
                    
                    Repeater {
                        model: root.columns
                        delegate: Rectangle {
                            id: workspace
                            required property int index
                            property int colIndex: index
                            property int workspaceValue: row.index * root.columns + colIndex + 1
                            property bool isActive: monitor.activeWorkspace?.id === workspaceValue
                            
                            width: root.workspaceImplicitWidth
                            height: root.workspaceImplicitHeight
                            color: isActive ? "#2a4a6a" : "#252525"
                            radius: 8
                            border.width: isActive ? 3 : 1
                            border.color: isActive ? "#4a9eff" : "#3a3a3a"
                            
                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                            
                            Behavior on border.color {
                                ColorAnimation { duration: 200 }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: workspace.workspaceValue
                                font {
                                    pixelSize: 80 * root.scale
                                    weight: Font.DemiBold
                                }
                                color: workspace.isActive ? "#ffffff" : "#505050"
                                opacity: 0.3
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    GlobalStates.overviewOpen = false
                                    Hyprland.dispatch(`workspace ${workspace.workspaceValue}`)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Windows overlay
        Item {
            id: windowSpace
            anchors.centerIn: parent
            width: workspaceColumnLayout.width
            height: workspaceColumnLayout.height
            
            Repeater {
                model: HyprlandData.windowList.filter(win => {
                    return win.workspace?.id > 0 && win.workspace?.id <= root.workspacesShown;
                })
                
                delegate: Loader {
                    id: windowLoader
                    required property var modelData
                    
                    property int workspaceId: modelData.workspace?.id ?? 1
                    property int rowIndex: Math.floor((workspaceId - 1) / root.columns)
                    property int colIndex: (workspaceId - 1) % root.columns
                    property real xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * colIndex
                    property real yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                    
                    sourceComponent: OverviewWindow {
                        toplevel: {
                            // Find the toplevel for this window
                            var toplevels = ToplevelManager.toplevels?.values ?? [];
                            for (var i = 0; i < toplevels.length; i++) {
                                var tl = toplevels[i];
                                if (tl.HyprlandToplevel && `0x${tl.HyprlandToplevel.address}` === windowLoader.modelData.address) {
                                    return tl;
                                }
                            }
                            return null;
                        }
                        windowData: windowLoader.modelData
                        monitorData: root.monitor
                        scale: root.scale
                        widgetMonitorWidth: root.monitor.width
                        widgetMonitorHeight: root.monitor.height
                        xOffset: windowLoader.xOffset
                        yOffset: windowLoader.yOffset
                    }
                }
            }
        }
    }
}
