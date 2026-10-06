pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "HyprlandDispatch.js" as HyprlandDispatch
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
    property real pressX: 0
    property real pressY: 0
    // Held so the grabbed image stays valid for as long as Drag.imageSource
    // points at it.
    property var dragImage: null
    property int dynamicZ: 0
    readonly property var currentWindowData: HyprlandData.windowByAddress[windowData?.address] ?? windowData

    // A real Wayland drag, not an in-scene one: the compositor drops the
    // pointer grab at the edge of the monitor the drag started on, so an
    // in-scene drag can never reach another monitor's overview. The drop is
    // handled by the DropArea in whichever OverviewWidget receives it.
    readonly property bool dragging: Drag.active

    // The drag takes over the grab, so the press ends in a cancel, not a release.
    onDraggingChanged: {
        if (!dragging) {
            isPressed = false;
            overviewWidget.draggingFromWorkspace = -1;
            GlobalStates.overviewDragTargetWorkspace = -1;
        }
    }

    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.MoveAction
    Drag.proposedAction: Qt.MoveAction
    Drag.mimeData: ({ "text/plain": String(windowData?.address ?? "") })
    
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

        onEntered: hovered = true
        onExited: hovered = false

        onPressed: mouse => {
            if (mouse.button !== Qt.LeftButton) return;
            wasDragged = false;
            root.pressX = mouse.x
            root.pressY = mouse.y
            dynamicZ = overviewWidget.requestTopZ()
            isPressed = true

            // Qt needs something to show under the cursor while dragging.
            root.grabToImage(result => {
                root.dragImage = result
                root.Drag.imageSource = result.url
            })
        }

        onPositionChanged: mouse => {
            if (!isPressed || root.Drag.active) return;
            if (Math.abs(mouse.x - root.pressX) + Math.abs(mouse.y - root.pressY) < Qt.styleHints.startDragDistance) return;

            wasDragged = true
            root.Drag.hotSpot.x = mouse.x
            root.Drag.hotSpot.y = mouse.y
            overviewWidget.draggingFromWorkspace = windowData?.workspace?.id ?? -1
            root.Drag.active = true
        }

        onReleased: isPressed = false
        onCanceled: isPressed = false

        onClicked: event => {
            if (!windowData) return;
            if (wasDragged) return;
            
            if (event.button === Qt.LeftButton) {
                GlobalStates.setOverviewOpen(false)
                Hyprland.dispatch(HyprlandDispatch.focusWindow(windowData.address, Hyprland.usingLua))
                event.accepted = true
            } else if (event.button === Qt.MiddleButton) {
                Hyprland.dispatch(HyprlandDispatch.closeWindow(windowData.address, Hyprland.usingLua))
                event.accepted = true
            }
        }
    }
}
