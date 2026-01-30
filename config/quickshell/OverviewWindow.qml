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
    property bool pressed: false
    
    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    
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
        border.color: pressed ? "#4a9eff" : hovered ? "#3a7acc" : "#3a3a3a"
        border.width: 2
        radius: 8
        
        // Color overlay for interactions
        Rectangle {
            anchors.fill: parent
            color: pressed ? "#4a9eff" : hovered ? "#3a7acc" : "transparent"
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
        
        onEntered: hovered = true
        onExited: hovered = false
        
        onPressed: mouse => {
            pressed = true
        }
        
        onReleased: {
            pressed = false
        }
        
        onClicked: event => {
            if (!windowData) return;
            
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
