pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "./services"

Item {
    id: root
    required property var toplevel
    required property var windowData
    required property var monitorData
    required property real scale
    required property real widgetMonitorWidth
    required property real widgetMonitorHeight
    required property var overviewWidget
    
    property real widthRatio: {
        const monitorScale = monitorData?.scale ?? 1
        const monitorWidth = monitorData?.width ?? 1
        return (widgetMonitorWidth * monitorScale) / (monitorWidth * widgetMonitorScale)
    }
    property real heightRatio: {
        const monitorScale = monitorData?.scale ?? 1
        const monitorHeight = monitorData?.height ?? 1
        return (widgetMonitorHeight * monitorScale) / (monitorHeight * widgetMonitorScale)
    }
    property real widgetMonitorScale: 1.0
    
    property real initX: Math.max((windowData?.at[0] - (monitorData?.x ?? 0)) * widthRatio * root.scale, 0) + xOffset
    property real initY: Math.max((windowData?.at[1] - (monitorData?.y ?? 0)) * heightRatio * root.scale, 0) + yOffset
    property real xOffset: 0
    property real yOffset: 0
    
    property real targetWindowWidth: windowData?.size[0] * scale * widthRatio
    property real targetWindowHeight: windowData?.size[1] * scale * heightRatio
    property bool hovered: false
    property bool isPressed: false
    property bool wasDragged: false
    // Last drag position in Hyprland layout coordinates, so the drop can land
    // on a workspace belonging to another monitor's overview.
    property real lastLayoutX: 0
    property real lastLayoutY: 0
    property int dynamicZ: 0
    readonly property var currentWindowData: HyprlandData.windowByAddress[windowData?.address] ?? windowData

    function trackDragPosition(mouse) {
        const scenePos = root.mapToItem(null, mouse.x, mouse.y);
        const layoutPos = overviewWidget.toLayoutPosition(scenePos.x, scenePos.y);
        root.lastLayoutX = layoutPos.x;
        root.lastLayoutY = layoutPos.y;
    }
    
    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    z: dynamicZ
    
    Behavior on x {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on width {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    
    Rectangle {
        anchors.fill: parent
        color: "#2a2a2a"
        border.color: isPressed ? "#4a9eff" : hovered ? "#3a7acc" : "#3a3a3a"
        border.width: 2
        radius: 8
        
        // Color overlay for interactions
        Rectangle {
            anchors.fill: parent
            color: isPressed ? "#4a9eff" : hovered ? "#3a7acc" : "transparent"
            opacity: 0.3
            radius: parent.radius
        }
        
        ScreencopyView {
            id: windowPreview
            anchors.fill: parent
            anchors.margins: 2
            captureSource: GlobalStates.overviewOpen ? root.toplevel : null
            live: false
        }
        
        // Window title
        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 2
            }
            height: 25
            color: "#1a1a1a"
            opacity: 0.9
            radius: 4
            
            Text {
                anchors.centerIn: parent
                text: currentWindowData?.title ?? ""
                color: "#ffffff"
                font.pixelSize: 12
                elide: Text.ElideRight
                width: parent.width - 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        drag.target: parent
        
        onEntered: hovered = true
        onExited: hovered = false

        onPressed: mouse => {
            if (mouse.button !== Qt.LeftButton) return;
            wasDragged = false;
            root.Drag.active = true
            root.Drag.source = root
            root.Drag.hotSpot.x = mouse.x
            root.Drag.hotSpot.y = mouse.y
            overviewWidget.draggingFromWorkspace = windowData?.workspace?.id ?? -1
            dynamicZ = overviewWidget.requestTopZ()
            isPressed = true
            root.trackDragPosition(mouse)
        }

        onPositionChanged: mouse => {
            if (root.Drag.active) {
                wasDragged = true
                root.trackDragPosition(mouse)
                GlobalStates.overviewDragTargetWorkspace = GlobalStates.overviewWorkspaceAt(
                    root.lastLayoutX,
                    root.lastLayoutY
                )
            }
        }
        
        onReleased: {
            isPressed = false
            if (root.Drag.active) {
                const targetWorkspace = GlobalStates.overviewWorkspaceAt(
                    root.lastLayoutX,
                    root.lastLayoutY
                )
                root.Drag.active = false
                overviewWidget.draggingFromWorkspace = -1
                GlobalStates.overviewDragTargetWorkspace = -1
                if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace?.id) {
                    Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${targetWorkspace}", window = "address:${windowData?.address}", follow = false })`)
                }
                // Snap back to computed position; data refresh will place it correctly.
                root.x = initX
                root.y = initY
            }
        }
        
        onClicked: event => {
            if (!windowData) return;
            if (wasDragged) return;
            
            if (event.button === Qt.LeftButton) {
                GlobalStates.setOverviewOpen(false)
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:${windowData.address}" })`)
                event.accepted = true
            } else if (event.button === Qt.MiddleButton) {
                Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${windowData.address}" })`)
                event.accepted = true
            }
        }
    }
}
