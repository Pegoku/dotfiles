pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

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
    property real lastMouseX: x + width / 2
    property real lastMouseY: y + height / 2
    property int dragZ: 99999
    
    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    z: isPressed ? dragZ : 0
    
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
            live: true
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
                text: windowData?.title ?? ""
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
            isPressed = true
        }

        onPositionChanged: mouse => {
            if (root.Drag.active) {
                wasDragged = true
                lastMouseX = root.x + mouse.x
                lastMouseY = root.y + mouse.y
                overviewWidget.draggingTargetWorkspace = overviewWidget.workspaceAtPosition(
                    lastMouseX,
                    lastMouseY
                )
            }
        }
        
        onReleased: {
            isPressed = false
            if (root.Drag.active) {
                const targetWorkspace = overviewWidget.workspaceAtPosition(
                    lastMouseX,
                    lastMouseY
                )
                root.Drag.active = false
                overviewWidget.draggingFromWorkspace = -1
                overviewWidget.draggingTargetWorkspace = -1
                if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace?.id) {
                    Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${windowData?.address}`)
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
                GlobalStates.overviewOpen = false
                Hyprland.dispatch(`focuswindow address:${windowData.address}`)
                event.accepted = true
            } else if (event.button === Qt.MiddleButton) {
                Hyprland.dispatch(`closewindow address:${windowData.address}`)
                event.accepted = true
            }
        }
    }
}
